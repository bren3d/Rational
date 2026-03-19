## Abstract class for behavior tree components. 
@abstract
@tool
@icon("../icons/RationalComponent.svg")
class_name RationalComponent extends Resource

enum {SUCCESS, FAILURE, RUNNING}

signal tree_changed

var block_tree_change_signal: bool = false

## Override this method to customize behavior when not receiving a tick...
@abstract func _no_tick(delta: float, board: Blackboard, actor: Node) -> int

## Override this method to customize tree behavior.
@abstract func _tick(delta: float, board: Blackboard, actor: Node) -> int

## Should not contain null components.
func get_children(recursive: bool = false) -> Array[RationalComponent]:
	return []

func notify_tree_changed() -> void:
	tree_changed.emit()

func has_child(comp: RationalComponent, recursive: bool = false) -> bool:
	if recursive:
		for child: RationalComponent in get_children():
			if child.has_child(comp, recursive):
				return true
	return comp in get_children()

func get_child(idx: int) -> RationalComponent:
	return get_children()[idx]

func get_child_count() -> int:
	return get_children().size()

func get_class_name() -> Array[StringName]:
	return [&"RationalComponent"]

func _get_configuration_warnings() -> PackedStringArray:
	return PackedStringArray()


func _set(property: StringName, value: Variant) -> bool:
	match property:
		&"resource_name":
			resource_name = value if value else get_class_name().back()
			emit_changed()
		&"resource_path":
			resource_path = value
			emit_changed()
	return false


## Do [b]not[/b] override this method, use [method _tick] instead.
func tick(delta: float, board: Blackboard, actor: Node) -> int:
	return SUCCESS

## Do [b]not[/b] override this method, use [method _no_tick] instead.
func no_tick(delta: float, board: Blackboard, actor: Node) -> int:
	return FAILURE
