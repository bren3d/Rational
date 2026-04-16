@tool
class_name TreeNode extends RefCounted

const RationalGraphNode := preload("graph_node.gd")
const TreePositionComponent := preload("tree_positioner.gd")

#region Static

static var _id_count: int = 0

static func generate_id() -> int:
	_id_count += 1
	return _id_count

static var _nodes: Dictionary[int, TreeNode]
static var _comps: Dictionary[RationalComponent, TreeNode]

static func from_id(_id: int) -> TreeNode:
	return _nodes.get(_id)

static func from_comp(comp: RationalComponent) -> TreeNode:
	return _comps.get(comp)

static func comp_has_node(comp: RationalComponent) -> bool:
	return TreeNode.from_comp(comp) != null

#endregion Static

signal visibility_changed

signal child_added
signal child_removed



var id: int = -1:
	set(val):
		if id == -1: 
			id = val
		

var _block_update: bool = false
var is_root: bool = false

var visible: bool = true: get = is_visible, set = set_visible


var component: RationalComponent: get = get_component, set = set_component

var graph_node: GraphElement: get = get_node, set = set_node
var positioner: TreePositionComponent = TreePositionComponent.new()

var parent: TreeNode: get = get_parent, set = set_parent
var children: Array[TreeNode]: get = get_children, set = set_children
func get_node() -> RationalGraphNode:
	return graph_node

func set_node(val: GraphElement) -> void:
	pass
func _init(_component: RationalComponent = null, _parent: TreeNode = null, _is_root: bool = false) -> void:
	id = generate_id()
	TreeNode._nodes[id] = self
	
	
	component = _component
	parent = _parent
	create_node(_is_root)

func get_index() -> int:
	return parent.children.find(self) if parent else -1

func get_child(index: int) -> TreeNode:
	if -get_child_count() <= index and index < get_child_count():
		return children[index]
	printerr("child index '%d' is out of bounds (arr_size = %s)" % [index, get_child_count()])
	return null

func can_parent(node: TreeNode) -> bool:
	return node and component.can_parent(node.component)

func add_child(node: TreeNode, index: int = -1) -> void:
	if not node:
		printerr("Cannot add null node.")
		return
	
	if not can_parent(node):
		printerr("%s cannot parent child %s." % [component, node])
		return
	
	if node.parent == self: 
		printerr("%s is already child to %s" % [node, self])
		return
	
	if index < -get_child_count() or get_child_count() < index:
		printerr("child index '%d' is out of bounds (arr_size = %s)" % [index, get_child_count()])
		return
	
	_block_update = true
	component.add_child(node.component, index)
	children.insert(index, node)
	node.parent = self
	_block_update = false


func remove_child(node: TreeNode) -> void:
	if not node:
		printerr("Cannot remove null node.")
		return
	
	if not node in children:
		printerr("Cannot remove node that is not childed.")
		return
	
	assert(node.parent == self)
	
	_block_update = true
	if component is Composite:
		component.remove_child(node.component)
	children.remove_at(children.find(node))
	node.parent = null
	_block_update = false


func get_children() -> Array[TreeNode]:
	return children

func get_child_count() -> int:
	return children.size()

func get_root() -> TreeNode:
	var root: TreeNode = self
	while root.get_parent():
		root = root.get_parent()
	return root

func get_tree_id() -> int:
	return get_root().id

func is_comp(comp: RationalComponent) -> bool:
	return comp == component

func is_visible_in_tree() -> bool:
	var node: TreeNode = self
	while node:
		if not node.visible:
			return false
		node = node.get_parent()
	return true

func is_visible() -> bool:
	return visible

func set_visible(val: bool) -> void:
	if visible == val: return
	visible = val
	visibility_changed.emit()

func set_children(val: Array[TreeNode]) -> void:
	var ignore_idx: PackedInt64Array
	for child in get_children():
		if not child in val:
			child.parent = null
	
	children = val.filter(is_instance_valid)
	
	for child in children:
		child.parent = self


func get_parent() -> TreeNode:
	return parent

func set_parent(val: TreeNode) -> void:
	if parent == val: return
	if parent:
		parent.child_removed.emit(self)
	
	parent = val
	
	if parent:
		parent.child_added.emit(self)
		positioner.parent = parent.positioner if parent else null

func get_component() -> RationalComponent:
	return component

func set_component(val: RationalComponent) -> void:
	if not val: return
	assert(not component, "Trying to change TreeNode component when one already exists.")
	if not val.is_built_in() and comp_has_node(val):
		printerr("RationalComponent %s already has TreeNode." % component)
	
	component = val
	component.children_changed.connect(_on_children_changed)
	update_children()

func create_node(is_root: bool = false) -> void:
	
	graph_node = RationalGraphNode.new()
	

func update_children() -> void:
	if _block_update or not component: return
	
	var childs: Array[RationalComponent] = component.get_children()
	
	var new_children: Array[TreeNode]
	new_children.resize(childs.size())
	
	for i: int in childs.size():
		new_children[i] = TreeNode.new(childs[i], self) if not TreeNode.comp_has_node(childs[i]) else TreeNode.from_comp(childs[i])

func _on_children_changed() -> void:
	update_children()

func _notification(what: int) -> void:
	match what:
		NOTIFICATION_PREDELETE:
			_comps.erase(component)
			_nodes.erase(id)
			if graph_node and not graph_node.is_queued_for_deletion():
				graph_node.queue_free()
