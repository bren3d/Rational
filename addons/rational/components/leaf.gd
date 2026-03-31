## Abstract class for [RationalComponent] with no children that typically 
## check conditions or perform actions.
@abstract
@tool
@icon("res://addons/rational/icons/Leaf.svg")
class_name Leaf extends RationalComponent

@abstract func _no_tick(delta: float, board: Blackboard, actor: Node) -> int

@abstract func _tick(delta: float, board: Blackboard, actor: Node) -> int
