@tool
extends RefCounted
## 

const Util := preload("../util.gd")

const FILENAME: String = "cache.cfg"
const SECTION: String = "root_data_list"
const KEY_ROOT_DATA: String = "roots"

signal root_added(root: RootData)
signal root_erased(root: RootData)

## Emitted when the current resource needs to be fetched again to apply updates to.
signal root_reloaded(root_data: RootData)

## Emited when [param root] needs to be saved via file dialog.
signal request_save_as(root: RationalComponent)

## Class icon textures.
var class_icons: Dictionary[StringName, Texture2D]

var root_data_list: Array[RootData]

var open_scenes: PackedStringArray

func _init() -> void:
	EditorInterface.get_file_system_dock().files_moved.connect(_on_file_moved)
	EditorInterface.get_file_system_dock().resource_removed.connect(_on_resource_removed)
	
	populate_class_icons()
	EditorInterface.get_resource_filesystem().script_classes_updated.connect(populate_class_icons, CONNECT_DEFERRED)
	open_scenes = EditorInterface.get_open_scenes()
	var plugin: EditorPlugin = Util.get_plugin()
	plugin.scene_changed.connect(_on_scene_changed)
	plugin.scene_closed.connect(_on_scene_closed)

#region Paths/Roots

func get_data(root: RationalComponent = null, path: String = "", default: RootData = null) -> RootData:
	for r: RootData in root_data_list:
		if r.is_root_or_path(root, path):
			return r
	return default

func has_data(root_data: RootData) -> bool:
	return get_data(root_data.root, root_data.path) != null

func path_get_data(path: String) -> RootData:
	for data: RootData in get_data_list():
		if data.is_path(path):
			return data
	return null

func has_path(path: String) -> bool:
	return path_get_data(path) != null

func root_get_data(root: RationalComponent) -> RootData:
	for data: RootData in get_data_list():
		if data.is_root(root):
			return data
	return null

func has_root(root: RationalComponent) -> bool:
	return root_get_data(root) != null

func has_root_or_path(root: RationalComponent, path: String) -> bool:
	return get_data(root, path) != null

func add_data(root_data: RootData) -> void:
	if not root_data or has_data(root_data): return
	
	if not root_data.root:
		printerr("Unable to load root at path: %s" % root_data.path)
		return
	
	var root_name_list: PackedStringArray
	for data: RootData in get_data_list():
		root_name_list.push_back(data.name)
	
	root_data.name = generate_unique_name(root_data.name, root_name_list)
	root_data_list.push_back(root_data)
	root_data.closed.connect(erase_data.bind(root_data), CONNECT_DEFERRED)
	root_data.request_save.connect(save_data, CONNECT_APPEND_SOURCE_OBJECT)
	root_added.emit(root_data)


func add_root(root: RationalComponent, path: String = "") -> void:
	if not root or has_root_or_path(root, path): return
	add_data(RootData.new(root, path))


func add_path(path: String) -> void:
	if not path or has_path(path): return
	add_data(load_root_data(path))


func erase_data(data: RootData) -> void:
	if not data or not has_data(data): return
	root_data_list.erase(data)
	root_erased.emit(data)

func erase_path(path: String) -> void:
	if not has_path(path): return
	erase_data(path_get_data(path))

func is_valid_path(path: String) -> bool:
	return path and ResourceLoader.exists(path, "RationalComponent")

func get_data_list() -> Array[RootData]:
	return root_data_list

func _on_file_moved(from: String, to: String) -> void:
	var data: RootData = path_get_data(from)
	if not data: 
		return
	data.set_resource_path(to)



#endregion Paths/Roots

#region Save/Load

func get_save_path() -> String:
	return get_script().resource_path.get_base_dir().path_join(FILENAME)

func save() -> void:
	var root_data: Array[Dictionary]
	for rd: RootData in root_data_list:
		root_data.push_back(rd.to_dict())

	var cfg: ConfigFile = ConfigFile.new()
	
	cfg.set_value(SECTION, KEY_ROOT_DATA, root_data)
	print("Saved cache => %s" % error_string(cfg.save(get_save_path())))

func load() -> void:
	var cfg: ConfigFile = ConfigFile.new()
	var err:= cfg.load(get_save_path())
	if err != OK:
		printerr("Error loading cache root_data_list => %s" % error_string(err))
		return
	
	var fs: EditorFileSystem = EditorInterface.get_resource_filesystem()
	while fs.is_scanning():
		await Engine.get_main_loop().process_frame
	
	for dict: Dictionary in cfg.get_value(SECTION, KEY_ROOT_DATA, []):
		add_data(RootData.from_dict(dict))

func save_data_as(data: RootData) -> void:
	if not data: return
	request_save_as.emit(data.root.duplicate(true))

func save_data(data: RootData) -> void:
	if not data: 
		return
	
	if not data.can_save():
		save_data_as(data)
		# New resource being saved should trigger signal and be added.
		return
	
	var path: String = data.path
	
	var err: int
	if path.contains("::"):
		var scene_path: String = path.get_slice("::", 0)
		if scene_path in EditorInterface.get_open_scenes():
			data.sync_path()
			EditorInterface.open_scene_from_path(scene_path)
			err = EditorInterface.save_scene()
		
		else:
			data.reload_no_signal()
			var packed_scene: PackedScene = load(scene_path)
			data.sync_path()
			err = ResourceSaver.save(packed_scene)
			data.reloaded.emit()
	else:
		err = ResourceSaver.save(data.root)
	
	data.unsaved_changes = err != OK
	print("Saved %s => %s" % [data, error_string(err)])

func load_root_data(path: String) -> RootData:
	if not path:
		return null
	var data: RootData = RootData.new(load_path(path), path)
	
	if not data.root:
		printerr("Unable to load root at path: %s" % path)
		return null
		
	return data

func load_path(path: String) -> RationalComponent:
	if not path: return null
	
	if ResourceLoader.exists(path):
		return ResourceLoader.load(path)
	
	var resource_paths: PackedStringArray = path.split("::")
	var scene_path: String = resource_paths[0]
	
	if not ResourceLoader.exists(scene_path, "PackedScene"):
		printerr("Broken scene path for RationalComponent: %s" % path)
		return null
	
	var state: SceneState = ResourceLoader.load(scene_path, "PackedScene").get_state()
	for i: int in state.get_node_count():
		for j: int in state.get_node_property_count(i):
			if state.get_node_property_value(i, j) is RationalComponent:
				var root: RationalComponent = state.get_node_property_value(i, j)
				if root.resource_path == path:
					return root.duplicate(true)
	
	return ResourceLoader.load(path)

#endregion Save/Load

#region icon

func has_icon(_class: StringName) -> bool:
	return _class in class_icons

func comp_get_class(comp: Object) -> String:
	return comp.get_script().get_global_name() if comp else ""

func comp_get_icon(comp: Object) -> Texture2D:
	return class_get_icon(comp_get_class(comp))

func data_get_icon(data: RootData) -> Texture2D:
	return class_get_icon(data.class_of_root) if data else null

func class_get_icon(_class: StringName) -> Texture2D:
	return class_icons.get(_class, class_icons.get(&"RationalComponent"))

func populate_class_icons() -> void:
	class_icons.clear()
	var class_list: Array[Dictionary] = ProjectSettings.get_global_class_list()
	
	for dict: Dictionary in class_list:
		if dict.class != &"RationalComponent": continue
		class_icons[&"RationalComponent"] = load(dict.icon)
	
	var base_classes: Array[StringName] = [&"RationalComponent"]
	while not base_classes.is_empty():
		var new_bases: Array[StringName] = []
		for dict: Dictionary in class_list:
			if dict.base in base_classes:
				new_bases.push_back(dict.class)
				class_icons[dict.class] = load(dict.icon) if dict.icon else class_icons[dict.base]
		base_classes = new_bases

#endregion icon

func _on_resource_removed(res: Resource) -> void:
	if res is RationalComponent:
		erase_data(get_data(res))

func _on_scene_changed(node: Node) -> void:
	if not node or not node.scene_file_path: return
	if not node.scene_file_path in open_scenes:
		open_scenes.push_back(node.scene_file_path)
		for data: RootData in get_data_list():
			if data.path.contains(node.scene_file_path):
				data.sync_path()

func _on_scene_closed(filepath: String) -> void:
	open_scenes.erase(filepath)
	for data: RootData in get_data_list():
		if data.get_resource_path().contains(filepath):
			data.reload_root()

func generate_unique_name(initial_name: String, name_list: PackedStringArray) -> String:
	if not initial_name: 
		return ""
	
	var base_name: String = initial_name
	var result: String = initial_name

	var i: int = 0
	while (i + 1) < result.length() and result.right(i + 1).is_valid_int():
		i += 1
		
	if i > 0:
		base_name = result.left(result.length() - i)
		i = result.right(i).to_int()
	
	while result in name_list:
		result = base_name + str(i)
		i += 1
	
	return result
