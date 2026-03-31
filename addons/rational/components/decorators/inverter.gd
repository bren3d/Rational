@tool
class_name Inverter extends Decorator
## [Decorator] that will return the opposite status of its child unless the child returns [member RUNNING].

func _no_tick(delta: float, board: Blackboard, actor: Node) -> int:
	if children.is_empty():
		return SUCCESS
	return children[0].no_tick(delta, board, actor)

func _tick(delta: float, board: Blackboard, actor: Node) -> int:
	if children.is_empty(): 
		return SUCCESS
	
	match children[0].tick(delta, board, actor):
		SUCCESS: return FAILURE
		FAILURE: return SUCCESS
	
	return RUNNING
