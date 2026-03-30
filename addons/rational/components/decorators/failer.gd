@icon("../../icons/Failer.svg")
@tool
class_name Failer extends Decorator
## [Decorator] that will always return [member FAILURE]. Inverse of [Succeeder].


func _no_tick(delta: float, board: Blackboard, actor: Node) -> int:
	return FAILURE

func _tick(delta: float, board: Blackboard, actor: Node) -> int:
	return FAILURE

func get_class_name() -> Array[StringName]:
	var names: Array[StringName] = super()
	names.push_back(&"Failer")
	return names
