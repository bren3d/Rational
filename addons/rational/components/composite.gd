@abstract
@tool
class_name Composite extends RationalComponent
## Type of [RationalComponent] that manages children.

@export var children: Array[RationalComponent]: set = set_children 

@abstract func _no_tick(delta: float, board: Blackboard, actor: Node) -> int

@abstract func _tick(delta: float, board: Blackboard, actor: Node) -> int

func can_parent(child: RationalComponent) -> bool:
	return not child or (child != self and not child.has_child(self, true))


func add_child(child: RationalComponent, idx: int = -1) -> void:
	if not child or not can_parent(child): return
	
	if child.has_child(self, true):
		child = child.duplicate(true) # Need to replace self with duplicate
	
	elif has_child(child):
		child = child.duplicate()
	
	if -1 < idx and idx < get_child_count():
		children.insert(idx, child)
	
	else: 
		children.push_back(child)
	
	child.tree_changed.connect(notify_tree_changed)
	children_changed.emit()
	notify_tree_changed()


func remove_child(child: RationalComponent) -> void:
	if not child or not has_child(child):
		return
	
	children.erase(child)
	
	child.tree_changed.disconnect(notify_tree_changed)
	children_changed.emit()
	notify_tree_changed()


func set_children(val: Array[RationalComponent]) -> void:
	val = val.filter(can_parent)
	if val == children: return
	
	for child: RationalComponent in children:
		if not child or child in val: continue
		child.tree_changed.disconnect(notify_tree_changed)
	
	children = val
	
	for child: RationalComponent in children:
		if not child: continue
		if not child.tree_changed.is_connected(notify_tree_changed):
			child.tree_changed.connect(notify_tree_changed)
	
	children_changed.emit()
	notify_tree_changed()

func get_child(idx: int) -> RationalComponent:
	assert(abs(idx) < children.size(), "Child index out of bounds.")
	return children[idx]


func move_child(child: RationalComponent, to_index: int) -> void:
	if not (-get_child_count() <= to_index and to_index < get_child_count()):
		printerr("The calculated index %s is out of bounds (the array has %s elements). Leaving the array untouched." % [to_index, get_child_count()]) 
		return
	
	var child_idx: int = get_child_index(child)
	var to_index_clamped: int = wrapi(to_index, 0, get_child_count())
	
	if child_idx == to_index_clamped: return
	
	children.remove_at(child_idx)
	children.insert(to_index_clamped, child)
	
	children_changed.emit()
	notify_tree_changed()


func setup(actor: Node, board: Blackboard) -> void:
	for child: RationalComponent in children:
		child.setup(actor, board)

func get_children(recursive: bool = false) -> Array[RationalComponent]:
	var result: Array[RationalComponent]
	for child: RationalComponent in children:
		if not child: continue
		result.push_back(child)
		
	if recursive:
		for child: RationalComponent in children:
			if not child: continue
			result += child.get_children(recursive)
			
	return result
