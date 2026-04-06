@tool
@icon("../icons/RationalTree.svg")
class_name RationalTree extends Node

signal tree_enabled
signal tree_disabled

signal ticked(value: int)

enum {SUCCESS, FAILURE, RUNNING}

@export var root: RationalComponent: set = set_root

# ALERT TBR DEBUG ONLY
@export_custom(0, "", PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_READ_ONLY)
var root_id: String:
	get(): return root.resource_path.get_slice("::", 1) if root else "" 

@export var actor: Node

@export var blackboard: Blackboard

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


func set_root(val: RationalComponent) -> void:
	root = val
	if root and Engine.is_editor_hint() and is_node_ready():
		root.set_meta(&"_path_data", {path = owner.get_path_to(self), property = "root"})


func set_disabled(val: bool) -> void:
	disabled = val
	
	if not Engine.is_editor_hint():
		set_process(!val)
	
	if disabled:
		tree_disabled.emit()
	else:
		tree_enabled.emit()
#
#func _get_property_list() -> Array[Dictionary]:
	#return [{name = "root_path", type = TYPE_STRING, usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_READ_ONLY}]
#
#func _get(property: StringName) -> Variant:
	#match property:
		#&"root_path":
			#return root.resource_path if root else ""
	#return null
##func 
