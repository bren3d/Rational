@tool
class_name NewTreeNode extends RefCounted

const SIBLING_DISTANCE: float = 200.0
const LEVEL_DISTANCE: float = 120.0

var x: float
var y: float
var mod: float

var parent: NewTreeNode
var children: Array[NewTreeNode]

var item: GraphNode

var scale: float = EditorInterface.get_editor_scale()

func _init(_item: GraphNode = null, _parent: NewTreeNode = null) -> void:
	parent = _parent
	item = _item

func has_children() -> bool:
	return not children.is_empty()

func is_most_left() -> bool:
	return not parent or parent.children.front() == self

func is_most_right() -> bool:
	return not parent or parent.children.back() == self

func get_previous_sibling() -> NewTreeNode:
	return null if is_most_left() else parent.children[parent.children.find(self) - 1]

func get_next_sibling() -> NewTreeNode:
	return null if is_most_right() else parent.children[parent.children.find(self) + 1]

func get_most_left_sibling() -> NewTreeNode:
	return parent.children.front() if parent else null

func get_most_right_sibling() -> NewTreeNode:
	return parent.children.back() if parent else null

func calculate_initial_x(node: NewTreeNode) -> void:
	for child in children:
		child.calculate_initial_x(child)
	
	x = 0 if is_most_left() else get_previous_sibling().x + 1
