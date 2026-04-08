@tool
class_name RootData extends RefCounted

## Emitted when data changed.
signal changed

signal tree_changed

signal request_edit

signal closed

signal unsaved_changes_changed

signal data_saved

var root: RationalComponent: set = set_root

var path: String: set = set_path, get = get_path

var uid: int = ResourceUID.INVALID_ID 

## Path to node & property containing the root. Used with [method Node.get_node_and_resource].
var node_path: String

var name: String: set = set_name

var class_of_root: StringName: set = set_class_of_root

var unsaved_changes: bool = false: set = set_unsaved_changes, get = has_unsaved_changes


func _init(_root: RationalComponent = null, _path: String = "", _node_path: String = "") -> void:
	node_path = _node_path
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


func get_root_class() -> String:
	return root.get_script().get_global_name() if root else ""


func rename(to_name: String) -> void:
	if to_name == name: return
	name = to_name
	set_unsaved_changes(true)


func set_root(val: RationalComponent) -> void:
		if root == val: return
		
		for con: Dictionary in get_incoming_connections():
			var obj: Object = con.signal.get_object()
			if obj is RationalComponent:
				con.signal.disconnect(con.callable)
		
		if val:
			
			root = val.duplicate(true)
			root.changed.connect(_on_root_changed)
			root.script_changed.connect(_on_root_script_changed)
			root.tree_changed.connect(_on_tree_changed)
		
		else:
			root = null
		
		set_block_signals(true)
		class_of_root = get_root_class()
		name = root.resource_name if root else ""
		if not name and class_of_root:
			name = class_of_root
		
		set_block_signals(false)
		changed.emit()


func get_path() -> String:
	return path

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
		var original_root := get_original_root()
		if original_root:
			original_root.resource_name = name
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
		var original_root: RationalComponent = get_original_root()
		if original_root:
			EditorInterface.set_object_edited(original_root, not val)
		unsaved_changes_changed.emit()

func copy_root_properties(from: RationalComponent, to: RationalComponent) -> void:
	for property: Dictionary in from.get_property_list():
		if property.name == &"resource_path": continue
		to.set(property.name, from.get(property.name))


func save(save_path: String = "") -> Error:
	if not save_path:
		save_path = path
	
	if not save_path:
		return ERR_FILE_BAD_PATH
	
	var save_copy: RationalComponent = root.duplicate(true)
	var err: Error = FAILED
	
	if save_path.contains("::"):
		
		var scene_path: String = path.get_slice("::", 0)
		if not ResourceLoader.exists(scene_path, "PackedScene"):
			printerr("RationalComponent '%s' scene path '%s' does not exist.")
			return ERR_DOES_NOT_EXIST
		
		if scene_path in EditorInterface.get_open_scenes():
			# Need to save before attempting to load Packed.
			EditorInterface.open_scene_from_path(scene_path)
			EditorInterface.save_scene()
		
		var packed: PackedScene = ResourceLoader.load(scene_path, "PackedScene")
		var scene_node: Node = packed.instantiate(PackedScene.GEN_EDIT_STATE_INSTANCE)
		
		# 0 - Node | 1 - Resource | 2 - Rest of path
		var node_and_resource: Array = scene_node.get_node_and_resource(node_path)
		
		if not node_and_resource[0] or not node_and_resource[1] is RationalComponent:
			printerr("No Node/Resource found at path '%s'." % node_path)
			scene_node.queue_free()
			return ERR_DOES_NOT_EXIST
		
		copy_root_properties(save_copy, node_and_resource[1])
		
		packed.pack(scene_node)
		err = ResourceSaver.save(packed, scene_path)
		scene_node.free()
		EditorInterface.reload_scene_from_path(scene_path)
		
	
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

func serialize() -> Dictionary:
	return {
		name = name,
		path = path,
		node_path = node_path,
		root = root,
		}

func get_original_root() -> RationalComponent:
	return RootData.load_path(get_path(), true)

static func deserialize(data: Dictionary) -> RootData:
	var data_root: RationalComponent = load_path(data.get("path", ""))
	return RootData.new(data_root if data_root else data.get("root"), data.get("path", ""), data.get("node_path", ""))

static func load_path(path: String, show_errors: bool = true) -> RationalComponent:
	if not path: return null
	
	if ResourceLoader.exists(path):
		return ResourceLoader.load(path, "RationalComponent")
	
	if not path.containsn("::"):
		if show_errors:
			printerr("Unable to load component at path %s." % path)
		return null
	
	var scene_path: String = path.get_slice("::", 0)
	
	if not ResourceLoader.exists(scene_path, "PackedScene"):
		if show_errors:
			printerr("Broken scene path for RationalComponent at '%s'." % path)
		return null
	
	# Iterating over the entire scene state was faster than instancing the scene node for a scene of this size. May need to test more on larger scenes.
	var state: SceneState = ResourceLoader.load(scene_path, "PackedScene").get_state()
	for i: int in state.get_node_count():
		for j: int in state.get_node_property_count(i):
			if state.get_node_property_value(i, j) is RationalComponent:
				var root: RationalComponent = state.get_node_property_value(i, j)
				if root.resource_path == path:
					return root
	
	return null

func duplicate(deep: bool = false) -> RootData:
	return RootData.new(root.duplicate(deep))

func _to_string() -> String:
	return "RootData: %s | Path %s" % [root, path]
