@icon("../../icons/StatusSuccess.svg")
@tool
class_name Succeeder extends Decorator
## [Decorator] that will always return [member SUCCESS]. Inverse of [Failer].


func _no_tick(delta: float, board: Blackboard, actor: Node) -> int:
	return SUCCESS


func _tick(delta: float, board: Blackboard, actor: Node) -> int:
	return SUCCESS


func get_class_name() -> Array[StringName]:
	var names: Array[StringName] = super()
	names.push_back(&"Succeeder")
	return names
