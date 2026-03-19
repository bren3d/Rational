@tool
class_name MoveAction extends ActionLeaf

@export_range(0.0, 200.0, 1.0, "suffix:px/s", "or_greater", "or_less") 
var speed: float = 50.0

func _tick(delta: float, board: Blackboard, actor: Node) -> int:
	var target_global_position: Vector2 = board.get_value("target_global_position", Vector2.ZERO)
	actor.global_position = actor.global_position.move_toward(target_global_position, speed)
	return SUCCESS if actor.global_position == target_global_position else RUNNING
