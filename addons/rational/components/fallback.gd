@icon("../icons/Fallback.svg")
@tool
class_name Fallback extends Composite
## Composite node that ticks each child in [member children] in order until the child does not return [member FAILURE]. 
## Returns [member FAILURE] only if all [member children] return [member FAILURE]. Inverse of [Sequence].


func _no_tick(delta: float, board: Blackboard, actor: Node) -> int:
	return FAILURE

func _tick(delta: float, board: Blackboard, actor: Node) -> int:
	for child: RationalComponent in children:
		var status: int = child.tick(delta, board, actor)
		if status != FAILURE: return status
	return SUCCESS

func get_class_name() -> Array[StringName]:
	var names: Array[StringName] = super()
	names.push_back(&"Fallback")
	return names
