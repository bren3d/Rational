## A [Leaf] that define a task to be performed by an actor.
## Their execution can run across multiple frame executions in which should 
## return [member RUNNING] until the action is completed.
@tool
@icon("../icons/ActionLeaf.svg")
class_name ActionLeaf extends Leaf

## Override this method to customize behavior when not receiving a tick.
func _no_tick(delta: float, board: Blackboard, actor: Node) -> int:
	return FAILURE

## Override this method to customize behavior when receiving a tick.
func _tick(delta: float, board: Blackboard, actor: Node) -> int:
	return SUCCESS


func get_class_name() -> Array[StringName]:
	var names: Array[StringName] = super()
	names.push_back(&"ActionLeaf")
	return names
