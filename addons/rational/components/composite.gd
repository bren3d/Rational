@abstract
@tool
class_name Composite extends RationalComponent
## Type of [RationalComponent] that manages children.

signal child_added(child: RationalComponent)
signal child_removed(child: RationalComponent)

@export var children: Array[RationalComponent]: set = set_children 

@abstract func _no_tick(delta: float, board: Blackboard, actor: Node) -> int

@abstract func _tick(delta: float, board: Blackboard, actor: Node) -> int

func can_parent(child: RationalComponent) -> bool:
	return child != null

## Negative indexes
func add_child(child: RationalComponent, idx: int = -1) -> void:
	if not can_parent(child): return
	
	if not (-1 <= idx and idx <= get_child_count()):
		printerr("The calculated index %s is out of bounds (the array has %s elements). Defaulting child to end of array." % [idx, get_child_count()])
		idx = -1
	
	# Need to replace self with duplicate to prevent infinite recursion.
	if child == self or child.has_child(self, true):
		child = child.duplicate(true)
	
	elif has_child(child):
		child = child.duplicate()
	
	if idx == -1:
		children.push_back(child)
	else:
		children.insert(idx, child)
	
	child.tree_changed.connect(notify_tree_changed)
	child_added.emit(child)
	children_changed.emit()
	notify_tree_changed()


func remove_child(child: RationalComponent) -> void:
	if not child: return
	
	var child_index: int = get_child_index(child)
	if child_index < 0:
		printerr("Cannot remove child not parented to '%s'." % self)
		return
	
	children.remove_at(child_index)
	
	child.tree_changed.disconnect(notify_tree_changed)
	child_removed.emit(child)
	children_changed.emit()
	notify_tree_changed()


func set_children(val: Array[RationalComponent]) -> void:
	val = val.filter(can_parent)
	if val == children: return
	
	var previous_children: Array[RationalComponent] = children
	children = val
	
	for child: RationalComponent in previous_children:
		if child in children: continue
		child.tree_changed.disconnect(notify_tree_changed)
		child_removed.emit(child)
	
	for child: RationalComponent in children:
		if child in previous_children: continue
		child.tree_changed.connect(notify_tree_changed)
		child_added.emit(child)
	
	children_changed.emit()
	notify_tree_changed()

func get_child(idx: int) -> RationalComponent:
	if not (-get_child_count() <= idx and idx < get_child_count()):
		printerr("The calculated index %s is out of bounds (the array has %s elements)." % [idx, get_child_count()]) 
		return null
	return children[idx]


func move_child(child: RationalComponent, to_index: int) -> void:
	if not has_child(child):
		printerr("Cannot move child not parented to '%s'." % self)
		return
	
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


func get_children(recursive: bool = false) -> Array[RationalComponent]:
	var result: Array[RationalComponent]
	for child: RationalComponent in children:
		if not child: continue
		result.push_back(child)
		if recursive:
			result.append_array(child.get_children(recursive))
	
	return result
