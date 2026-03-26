## Abstract class for behavior tree components. 
@abstract
@tool
@icon("../icons/RationalComponent.svg")
class_name RationalComponent extends Resource

enum {SUCCESS, FAILURE, RUNNING}

signal tree_changed
signal children_changed

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

func can_parent(child: RationalComponent) -> bool:
	return false

func get_child(idx: int) -> RationalComponent:
	return get_children()[idx]

func get_child_count() -> int:
	return get_children().size()

func move_child(child: RationalComponent, to_index: int) -> void:
	pass

func print_tree_pretty() -> void:
	prints(get_tree_string_pretty("", true))


func get_tree_string_pretty(prefix: String, is_last: bool) -> String:
	var prefix_extension: String = " ┖╴" if is_last else " ┠╴"
	var tree_string: String = prefix + prefix_extension + resource_name + "\n"
	prefix_extension = "   " if is_last else " ┃ "
	for i: int in get_child_count():
		tree_string += get_child(i).get_tree_string_pretty(prefix + prefix_extension, i == get_child_count() - 1)
	return tree_string

func get_class_name() -> Array[StringName]:
	return [&"RationalComponent"]

func _get_configuration_warnings() -> PackedStringArray:
	return PackedStringArray()


func _set(property: StringName, value: Variant) -> bool:
	match property:
		&"local_to_scene":
			resource_local_to_scene = false
			return true
		&"resource_name":
			resource_name = value if value else get_class_name().back()
			emit_changed()
		&"resource_path":
			resource_path = value
			emit_changed()
	return false

func _validate_property(property: Dictionary) -> void:
	match property.name:
		&"resource_local_to_scene", &"resource_name":
			property.usage &= ~PROPERTY_USAGE_EDITOR


func _to_string() -> String:
	return "%s (%s)%s" % [resource_name, get_script().get_global_name(), " | %s" % resource_path if resource_path else ""]

## Do [b]not[/b] override this method, use [method _tick] instead.
func tick(delta: float, board: Blackboard, actor: Node) -> int:
	var result: int = _tick(delta, board, actor)
	RationalDebuggerMessages.process_tick(get_instance_id(),  result, board.get_data())
	return result

## Do [b]not[/b] override this method, use [method _no_tick] instead.
func no_tick(delta: float, board: Blackboard, actor: Node) -> int:
	#var result: int = _no_tick(delta, board, actor)
	#RationalDebuggerMessages.process_tick(get_instance_id(),  result, board.get_data())
	return _no_tick(delta, board, actor)
