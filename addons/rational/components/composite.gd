@abstract
@tool
class_name Composite extends RationalComponent
## Type of [RationalComponent] that manages children.

@export var children: Array[RationalComponent]: set = set_children 

@abstract func _no_tick(delta: float, board: Blackboard, actor: Node) -> int

@abstract func _tick(delta: float, board: Blackboard, actor: Node) -> int

func can_parent(child: RationalComponent) -> bool:
	return not child or not child.has_child(self, true) 


func add_child(child: RationalComponent, idx: int = -1) -> void:
	if not child or not can_parent(child): return
	
	if has_child(child):
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

# NOTE: Overriding since children can contain null.

func get_child_index(child: RationalComponent) -> int:
	return children.find(child)

func get_child(idx: int) -> RationalComponent:
	return children[idx]

func get_child_count() -> int:
	return children.size()


func move_child(child: RationalComponent, to_index: int = -1) -> void:
	var child_idx: int = children.find(child)
	if child_idx == to_index or to_index < 0: return
	children.remove_at(child_idx)
	children.insert(to_index, child)
	
	children_changed.emit()
	notify_tree_changed()


func setup(actor: Node, board: Blackboard) -> void:
	for child: RationalComponent in children:
		child.setup(actor, board)


func _get_configuration_warnings() -> PackedStringArray:
	return PackedStringArray(["Children empty"]) if children.is_empty() else PackedStringArray()


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


func get_class_name() -> Array[StringName]:
	var names: Array[StringName] = super()
	names.push_back(&"Composite")
	return names
