@tool
class_name RootData extends RefCounted

## Emitted when data changed.
signal changed

## Emitted when resource has changed and needs to have any pending changeds applied. Not emitted after saving.
signal reloaded

signal tree_changed

signal request_edit

signal request_save

signal closed

signal unsaved_changes_changed

var root: RationalComponent: set = set_root


var path: String: set = set_path


var name: String: set = set_name


var class_of_root: StringName: set = set_class_of_root


var unsaved_changes: bool = false: set = set_unsaved_changes



func _init(_root: RationalComponent = null, _path: String = "") -> void:
	root = _root
	path = _path if _path or not root else root.resource_path 


func is_root(_root: RationalComponent) -> bool:
	return root == _root


func is_path(_path: String) -> bool:
	return path and path == _path 


func is_root_or_path(_root: RationalComponent, _path: String) -> bool:
	return is_root(_root) or is_path(_path)


func can_save() -> bool:
	return path != ""


func is_desync() -> bool:
	return path and path == get_resource_path()


func sync_path() -> void:
	if not is_desync(): return
	set_block_signals(true)
	root.take_over_path(path)
	set_block_signals(false)


func set_no_signal(property: StringName, value: Variant) -> void:
	set_block_signals(true)
	set(property, value)
	set_block_signals(false)


func reload_root() -> void:
	if get_resource_path(): return
	reload_no_signal()
	reloaded.emit()
	changed.emit()


func reload_no_signal() -> void:
	if get_resource_path(): return
	set_no_signal(&"root", root.duplicate(true))


func get_resource_path() -> String:
	return root.resource_path


func set_resource_path(to_path: String) -> void:
	if not root: return
	root.resource_path = to_path


func get_root_class() -> String:
	return root.get_script().get_global_name() if root else ""


func to_dict() -> Dictionary:
	return {root = root, path = path}


static func from_dict(dict: Dictionary) -> RootData:
	return RootData.new(dict.get("root"), dict.get("path", ""))


func set_root(val: RationalComponent) -> void:
		if root == val: return
		if root:
			root.changed.disconnect(_on_root_changed)
			root.script_changed.disconnect(_on_root_script_changed)
			root.tree_changed.disconnect(_on_tree_changed)
		
		root = val
		
		if root:
			root.changed.connect(_on_root_changed)
			root.script_changed.connect(_on_root_script_changed)
			root.tree_changed.connect(_on_tree_changed)
		
		set_block_signals(true)
		class_of_root = root.get_script().get_global_name() if root else &""
		name = root.resource_name if root else ""
		if not name and class_of_root:
			name = class_of_root
		set_block_signals(false)
		changed.emit()


func set_path(val: String) -> void:
		if val and path == val: return
		path = val
		changed.emit()


func set_name(val: String) -> void:
		if name == val: return
		name = val if val else root.get_script().get_global_name()
		if root:
			root.resource_name = name


func set_class_of_root(val: String) -> void:
		if class_of_root == val: return
		class_of_root = val
		changed.emit()


func set_unsaved_changes(val: bool) -> void:
		if unsaved_changes == val: return
		unsaved_changes = val
		unsaved_changes_changed.emit()


func _to_string() -> String:
	return "RootData: %s | Path %s" % [root, path]


func _on_root_changed() -> void:
	if not root: return
	name = root.resource_name
	path = root.resource_path


func _on_tree_changed() -> void:
	tree_changed.emit()


func _on_root_script_changed() -> void:
	class_of_root = get_root_class()
