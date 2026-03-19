@abstract
@tool
class_name Composite extends RationalComponent
## Type of [class RationalComponent] that manages children.

@export var children: Array[RationalComponent]: set = set_children 

@abstract func _no_tick(delta: float, board: Blackboard, actor: Node) -> int

@abstract func _tick(delta: float, board: Blackboard, actor: Node) -> int


func set_children(val: Array[RationalComponent]) -> void:
	var i: int = val.size()
	while i > 0:
		i -= 1
		if not val[i]: continue
		if val[i].has_child(self, true):
			push_warning("%s cannot be ancestor to itself." % self)
			val.remove_at(i)
	
	for child: RationalComponent in children:
		if not child or child in val: continue
		child.tree_changed.disconnect(notify_tree_changed)
	
	
	children = val
	
	
	for child: RationalComponent in children:
		if not child: continue
		if not child.tree_changed.is_connected(notify_tree_changed):
			child.tree_changed.connect(notify_tree_changed)
	
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
