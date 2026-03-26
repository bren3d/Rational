@tool
class_name RootData extends RefCounted

## Editor meta data of the dictionary with [code]path[/code] and [code]property[/code]
const META_PATH: StringName = &"_path_data"

#const Util:= preload("../util.gd")
const META_ROOT: StringName = &"_is_root"

## Emitted when data changed.
signal changed

signal tree_changed

signal request_edit

signal data_saved

signal closed

signal unsaved_changes_changed


var root: RationalComponent: set = set_root


var path: String: set = set_path


var name: String: set = set_name


var class_of_root: StringName: set = set_class_of_root


var unsaved_changes: bool = false: set = set_unsaved_changes, get = has_unsaved_changes

var is_scene_subresource: bool = false


func _init(_root: RationalComponent = null, _path: String = "", node_path_data: Dictionary = {}) -> void:
	#printt(_root, _path)
	if not node_path_data.is_empty() and _root:
		_root.set_meta(META_PATH, node_path_data)
	path = _path if _path or not _root else _root.resource_path
	root = _root if _root else load_path(_path) 


func is_root(_root: RationalComponent) -> bool:
	return _root and ((path and _root.resource_path == path) or root == _root) 


func is_path(_path: String) -> bool:
	return path and path == _path 


func is_root_or_path(_root: RationalComponent, _path: String) -> bool:
	return is_root(_root) or is_path(_path)


func can_save() -> bool:
	return path != ""

func get_resource_path() -> String:
	return root.resource_path


func set_resource_path(to_path: String) -> void:
	if not root: return
	root.resource_path = to_path


func get_root_class() -> String:
	return root.get_script().get_global_name() if root else ""

func set_root(val: RationalComponent) -> void:
		if root == val: return
		
		for con: Dictionary in get_incoming_connections():
			var obj: Object = con.signal.get_object()
			if obj is RationalComponent:
				con.signal.disconnect(con.callable)
		
		if val:
			#val.changed.connect(_on_root_changed, CONNECT_APPEND_SOURCE_OBJECT)
			root = val.duplicate(true)
			root.changed.connect(_on_root_changed)
			root.script_changed.connect(_on_root_script_changed)
			root.tree_changed.connect(_on_tree_changed)
			root.set_meta(META_ROOT, true)
		
		else:
			root = null
		
		set_block_signals(true)
		class_of_root = get_root_class()
		name = root.resource_name if root else ""
		if not name and class_of_root:
			name = class_of_root
		
		set_block_signals(false)
		changed.emit()


func set_path(val: String) -> void:
	if not val or path == val: return
	path = val
	changed.emit()


func set_name(val: String) -> void:
		if name == val: return
		name = val
		if root:
			if not name:
				name = get_root_class()
			root.resource_name = name
		changed.emit()


func set_class_of_root(val: String) -> void:
		if class_of_root == val: return
		class_of_root = val
		changed.emit()


func has_unsaved_changes() -> bool:
	return unsaved_changes

func set_unsaved_changes(val: bool) -> void:
		if unsaved_changes == val: return
		unsaved_changes = val
		unsaved_changes_changed.emit()



func get_node_path() -> String:
	return root.get_meta(META_PATH, {}).get("path", "") if root else ""

func copy_root_properties(from: RationalComponent, to: RationalComponent) -> void:
	for property: Dictionary in from.get_property_list():
		if property.name == &"resource_path": continue
		to.set(property.name, from.get(property.name))


func save(save_path: String = "") -> Error:
	if not save_path:
		save_path = path
	
	var save_copy: RationalComponent = root.duplicate(true)
	var err: Error = FAILED
	
	if save_path.contains("::"):
		var scene_path: String = path.get_slice("::", 0)
		var path_data: Dictionary = get_meta(META_PATH, {path = ^"", property = ""})
		var scene_node: Node
		var packed: PackedScene
		for node: Node in EditorInterface.get_open_scene_roots():
			if node.scene_file_path == scene_path:
				scene_node = node
		
		if not scene_node:
			packed = ResourceLoader.load(scene_path, "PackedScene", ResourceLoader.CACHE_MODE_IGNORE)
			scene_node = packed.instantiate(PackedScene.GEN_EDIT_STATE_DISABLED)
		
		if not scene_node.has_node(path_data.path):
			printerr("No node found: %s" % path_data.path)
			return err
		
		var cached_ref: RationalComponent = scene_node.get_node(path_data.path).get(path_data.property)
		
		copy_root_properties(save_copy, cached_ref)
		
		scene_node.get_node(path_data.path).notify_property_list_changed()
		
		if packed:
			packed.pack(scene_node)
			err = ResourceSaver.save(packed, scene_path, ResourceSaver.FLAG_REPLACE_SUBRESOURCE_PATHS)
			scene_node.free()
		
		else:
			var current_scene: String = EditorInterface.get_edited_scene_root().scene_file_path
			EditorInterface.open_scene_from_path(scene_path)
			EditorInterface.mark_scene_as_unsaved()
			EditorInterface.open_scene_from_path(current_scene)
			err = OK
	
	else:
		if ResourceLoader.has_cached(save_path):
			var cached_ref: RationalComponent = ResourceLoader.get_cached_ref(save_path)
			copy_root_properties(save_copy, cached_ref)
			err = ResourceSaver.save(cached_ref, save_path)
		
		else:
			err = ResourceSaver.save(save_copy, save_path, ResourceSaver.FLAG_CHANGE_PATH)
	
	if err == OK:
		set_unsaved_changes(false)
		data_saved.emit()
	else:
		print("Error saving %s => %s" %[self, error_string(err)])
	
	return err


func _on_root_changed() -> void:
	if not root: return
	name = root.resource_name
	path = root.resource_path

func _on_root_script_changed() -> void:
	class_of_root = get_root_class()

func _on_tree_changed() -> void:
	set_unsaved_changes(true)
	tree_changed.emit()

func _on_cached_root_tree_changed(comp: RationalComponent = null) -> void:
	print("Cached root tree_changed: %s" % comp)

func _on_cached_root_changed(comp: RationalComponent = null) -> void:
	if not comp: return
	print("Cached root changed: %s" % comp)
	name = comp.resource_name
	path = comp.resource_path

func serialize() -> Dictionary:
	return {
		name = name,
		path = path,
		root = root,
		node_path_data = get_meta(META_PATH, {}),
		}


static func deserialize(data: Dictionary) -> RootData:
	var data_path: String = data.get("path", "")
	if data_path:
		var loaded_root: RationalComponent = load_path(data_path)
		if loaded_root:
			return RootData.new(loaded_root, data_path, data.get("node_path_data", {}))
	
	return RootData.new(data.get("root"), data_path, data.get("node_path_data", {}))


static func load_path(path: String) -> RationalComponent:
	if not path: return null
	
	if ResourceLoader.exists(path):
		return ResourceLoader.load(path, "RationalComponent", ResourceLoader.CACHE_MODE_REUSE)
	
	if not path.containsn("::"):
		printerr("Unable to load component at path %s." % path)
		return null
	
	var scene_path: String = path.get_slice("::", 0)
	
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

func _to_string() -> String:
	return "RootData: %s | Path %s" % [root, path]
