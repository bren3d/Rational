## A type of [Composite] that changes the response received from a single child.
@abstract
@tool
class_name Decorator extends Composite

@abstract func _no_tick(delta: float, board: Blackboard, actor: Node) -> int

@abstract func _tick(delta: float, board: Blackboard, actor: Node) -> int

func add_child(child: RationalComponent, idx: int = -1) -> void:
	if not can_parent(child): return
	if not children.is_empty() and children[0]:
		children[0].tree_changed.disconnect(notify_tree_changed)
	children.clear()
	super(child)

func remove_child(child: RationalComponent) -> void:
	if not child or not has_child(child):
		return
	child.tree_changed.disconnect(notify_tree_changed)
	children.clear()
	children_changed.emit()
	notify_tree_changed()

## Do nothing because there should only be one child/index.
func move_child(child: RationalComponent, to_index: int) -> void:
	assert(children.size() < 2, "Decorator should not have more than 1 child.")
