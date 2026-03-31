@icon("../../icons/Succeeder.svg")
@tool
class_name Succeeder extends Decorator
## [Decorator] that will always return [member SUCCESS]. Inverse of [Failer].

func _no_tick(delta: float, board: Blackboard, actor: Node) -> int:
	return SUCCESS

func _tick(delta: float, board: Blackboard, actor: Node) -> int:
	return SUCCESS
