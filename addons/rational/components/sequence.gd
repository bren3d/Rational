## Composite node that ticks each child in [member children] in order until the child does not return [member SUCCESS]. 
## Returns [member SUCCESS] only if all [member children] return [member SUCCESS]. Inverse of [Fallback].
@tool
@icon("../icons/Sequence.svg")
class_name Sequence extends Composite

func _no_tick(delta: float, board: Blackboard, actor: Node) -> int:
	return FAILURE

func _tick(delta: float, board: Blackboard, actor: Node) -> int:
	for child: RationalComponent in children:
		var status: int = child.tick(delta, board, actor)
		if status != SUCCESS: return status
	return SUCCESS
