@tool
@icon("../icons/Tree.svg")
class_name RationalTree extends Node

signal tree_enabled
signal tree_disabled

signal ticked(value: int)

enum {SUCCESS, FAILURE, RUNNING}

@export var actor: Node

@export var blackboard: Blackboard

@export var root: RationalComponent: set = set_root

@export var disabled: bool = true: set = set_disabled


func _ready() -> void:
	if not Engine.is_editor_hint(): return
	set_process(false)
	if not actor:
		actor = get_parent()


func _process(delta: float) -> void:
	if can_tick():
		assert(blackboard, "No blackboard set.")
		ticked.emit(root.tick(delta, blackboard, actor))


func can_tick() -> bool:
	return not disabled and root


## Propagates call to all tree components
func call_tree(method: StringName, args: Array = []) -> void:
	for child: RationalComponent in root.get_children(true):
		child.callv(method, args)
	
	root.callv(method, args)

func get_root_path() -> String:
	if not root:
		return ""
	if not root.resource_path:
		root.generate_scene_unique_id()
	return root.resource_path

func set_root(val: RationalComponent) -> void:
	root = val
	if root:
		if not root.resource_name:
			root.resource_name = name
	
		if not root.resource_path:
			root.generate_scene_unique_id()


func set_disabled(val: bool) -> void:
	disabled = val
	
	if not Engine.is_editor_hint():
		set_process(!val)
	
	if disabled:
		tree_disabled.emit()
	else:
		tree_enabled.emit()


func get_class_name() -> Array[StringName]:
	return [&"RationalTree"]

func _property_can_revert(property: StringName) -> bool:
	match property:
		&"actor": return actor == get_parent()
	return false

func _property_get_revert(property: StringName) -> Variant:
	match property:
		&"actor": return get_parent()
	return null
