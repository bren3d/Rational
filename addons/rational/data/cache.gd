@tool
extends RefCounted
## 


const Util := preload("../util.gd")

const ClassData := preload("rational_class_data.gd")
const ShortcutData := preload("shortcut_data.gd")


const FILENAME: String = "cache.cfg"
const SECTION: String = "root_data_list"
const KEY_ROOT_DATA: String = "roots"

signal data_added(data: RootData)
signal data_erased(data: RootData)

signal data_saved(data: RootData)
signal data_closed(data: RootData)

## Emitted when the current resource needs to be fetched again to apply updates to.
signal root_reloaded(root_data: RootData)

## Emited when [param root] needs to be saved via file dialog.
signal request_save_as(data: RationalComponent)

## Emitted when 
signal edited_tree_changed(data: RootData)

var class_data: ClassData

var shortcut_data: ShortcutData

## Class icon textures.
var class_icons: Dictionary[StringName, Texture2D]

var root_data_list: Array[RootData]

var edited_tree: RootData: set = set_edited_tree


func set_edited_tree(val: RootData) -> void:
	if edited_tree == val: return
	
	if not val in root_data_list:
		add_data(val)
	
	edited_tree = val
	
	edited_tree_changed.emit(val)
	
	if edited_tree:
		edited_tree.request_edit.emit()


func edit_tree(tree_data: RootData) -> void:
	if not tree_data: return
	set_edited_tree(tree_data)

func edit_root(root: RationalComponent) -> void:
	if not has_root(root):
		add_root(root)
	
	edit_tree(root_get_data(root))

func edit_rational_tree(tree: RationalTree) -> void:
	if not tree: return
	edit_root(tree.root)

func _init() -> void:
	EditorInterface.get_file_system_dock().files_moved.connect(_on_file_moved)
	EditorInterface.get_file_system_dock().resource_removed.connect(_on_resource_removed)
	class_data = ClassData.new()
	shortcut_data = ShortcutData.new()


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
	root_data.closed.connect(erase_data, CONNECT_APPEND_SOURCE_OBJECT | CONNECT_DEFERRED)
	
	data_added.emit(root_data)


func add_root(root: RationalComponent, path: String = "") -> void:
	if not root or has_root_or_path(root, path): return
	add_data(RootData.new(root, path if path else root.resource_path))


func add_path(path: String) -> void:
	if not path or has_path(path): return
	add_data(load_root_data(path))


func erase_data(data: RootData) -> void:
	if not data or not has_data(data): return
	root_data_list.erase(data)
	
	if edited_tree == data:
		set_edited_tree(null)
	
	data_erased.emit(data)

func erase_path(path: String) -> void:
	if not has_path(path): return
	erase_data(path_get_data(path))

func is_valid_path(path: String) -> bool:
	return path and ResourceLoader.exists(path, "RationalComponent")

func get_data_list() -> Array[RootData]:
	return root_data_list

func _on_file_moved(from: String, to: String) -> void:
	var data: RootData = path_get_data(from)
	if not data or not data.root: 
		return
	data.path = to


#endregion Paths/Roots

#region Save/Load

func get_save_path() -> String:
	return get_script().resource_path.get_base_dir().path_join(FILENAME)

func save() -> void:
	var root_data: Array[Dictionary]
	for rd: RootData in root_data_list:
		root_data.push_back(rd.serialize())

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
		add_data(RootData.deserialize(dict))

func save_data_as(data: RootData) -> void:
	if not data: return
	#if data.path:
		#data = data.duplicate(false)
		#data.data_saved.connect(add_data, CONNECT_APPEND_SOURCE_OBJECT | CONNECT_ONE_SHOT)
	request_save_as.emit(data)


func load_root_data(path: String) -> RootData:
	if not path:
		return null
	var data: RootData = RootData.new(null, path)
	
	if not data.root:
		printerr("Unable to load root at path: %s" % path)
		return null
	
	return data

func load_path(path: String) -> RationalComponent:
	if not path: return null
	
	if ResourceLoader.exists(path):
		return ResourceLoader.load(path, "RationalComponent")
	
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
					return root
	
	return null

#endregion Save/Load


func _on_resource_removed(res: Resource) -> void:
	if res is RationalComponent:
		erase_data(get_data(res))

func _on_data_request_edit(data: RootData) -> void:
	edit_tree(data)

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
		i += 1
		result = base_name + str(i)
	
	return result

#region icon

func class_extends_rational_component(_class: StringName) -> bool:
	return class_data.class_extends_rational_component(_class)

func has_icon(_class: StringName) -> bool:
	return class_data.class_has_icon(_class)

func comp_get_class(comp: Object) -> String:
	return class_data.comp_get_class(comp)

func comp_get_icon(comp: Object) -> Texture2D:
	return class_data.comp_get_icon(comp)

func data_get_icon(data: RootData) -> Texture2D:
	return class_get_icon(data.class_of_root) if data else null

func class_get_icon(_class: StringName) -> Texture2D:
	return class_data.class_get_icon(_class)

#endregion icon
