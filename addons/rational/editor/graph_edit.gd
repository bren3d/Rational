@tool
extends GraphEdit

#signal preview_created(root: RootData, preview: Image)

const EditorStyle = preload("editor_style.gd")
const RationalGraphNode := preload("graph_node.gd")
const CreatePopup = preload("create_popup.gd")

const PROGRESS_SHIFT: int = 50
const PORT_RANGE: float = 10

const HORIZONTAL_LAYOUT_ICON := preload("icons/horizontal_layout.svg")
const VERTICAL_LAYOUT_ICON := preload("icons/vertical_layout.svg")

signal selected_changed(nodes: Array[RationalComponent])

@export var popup: CreatePopup

var style: EditorStyle
var layout_button: Button

var updating_graph: bool = false
var arranging_nodes: bool = false

var horizontal_layout: bool = false:
	set(value):
		if updating_graph or arranging_nodes:
			return
		if horizontal_layout == value:
			return
		horizontal_layout = value
		update_layout_button()
		update_graph()

var active_root: RootData: set = set_active_root

var graph_states: Dictionary[RootData, Dictionary]

#var is_hovering_input_port: bool = false
#var is_hovering_output_port: bool = false

var is_dragging_connection: bool = false
var connection_start_position: Vector2

var create_popup_start_position: Vector2

var block_selection_signal: bool = false


func _ready() -> void:
	style = EditorStyle.new()
	
	custom_minimum_size = Vector2(200, 300)
	#show_arrange_button = false
	layout_button = Button.new()
	layout_button.flat = true
	layout_button.focus_mode = Control.FOCUS_NONE
	layout_button.pressed.connect(toggle_layout)
	update_layout_button()
	get_menu_hbox().add_child(layout_button)
	
	connection_drag_started.connect(_on_connection_drag_started)
	connection_request.connect(_on_connection_request)
	connection_drag_ended.connect(_on_connection_drag_ended)
	delete_nodes_request.connect(_on_delete_nodes_request)
	node_selected.connect(_on_node_selection_changed)
	node_deselected.connect(_on_node_selection_changed)
	#begin_node_move.connect(_on_begin_node_move)
	#end_node_move.connect(_on_end_node_move)
	
	popup.node_created.connect(_on_node_created)

func _on_on_begin_node_move() -> void:
	pass

func _on_on_end_node_move() -> void:
	pass



func _on_node_selection_changed(node: Node) -> void:
	if block_selection_signal: return
	selected_changed.emit(get_selected_components())


func _on_node_dragged(from: Vector2, to: Vector2, node: RationalGraphNode) -> void:
	print("%s dragged %v => %v" % [node.component.resource_name, from, to])
	update_node_index(node)


func update_node_index(node: RationalGraphNode) -> void:
	var parent: RationalGraphNode = node_get_parent(node.name)
	
	if not parent:
		return
	
	parent.component.move_child(node.component, node_get_index(node))


func node_get_index(node: RationalGraphNode) -> int:
	var parent: RationalGraphNode = node_get_parent(node.name)
	
	if not parent:
		return -1
	
	var children : Array[RationalGraphNode] = node_get_connected_children(parent)
	children.sort_custom(sort_position)
	return children.find(node)

func sort_position(node_a: RationalGraphNode, node_b: RationalGraphNode) -> bool:
	return node_a.position_offset.x < node_b.position_offset.x if horizontal_layout else node_a.position_offset.y < node_b.position_offset.y


func node_arrange_children(node: RationalGraphNode) -> void:
	if not node: return
	
	#var children: Dictionary[RationalComponent, RationalGraphNode] 
	
	#for child: RationalComponent in node.component.get_children():
		#children[child] = comp_get_graph_node(child)
	
	


func _on_end_node_move() -> void:
	pass



func open_create_popup(at_position: Vector2) -> void:
	if not active_root: return
	create_popup_start_position = at_position - global_position
	popup.popup_at_position(at_position)
	

func _on_node_created(comp: RationalComponent) -> void:
	print_rich("[color=green]Node Created: %s[/color]" % comp)
	var node: RationalGraphNode = add_node(comp)
	node.position_offset = (create_popup_start_position + scroll_offset)  / zoom

func _on_connection_drag_started(from_node: StringName, from_port: int, is_output: bool) -> void:
	var node: RationalGraphNode = get_node(String(from_node))
	connection_start_position = get_node_port_position(node, is_output) * zoom
	is_dragging_connection = true
	queue_redraw()

func _on_connection_drag_ended() -> void:
	is_dragging_connection = false
	queue_redraw()

func _on_connection_request(from_node: StringName, from_port: int, to_node: StringName, to_port: int) -> void:
	if not from_port == to_port and from_port == 0:
		printerr("Attempting to connect graph node port != 0.")
		return
	
	node_add_child(from_node, to_node)

func _on_delete_nodes_request(nodes: Array[StringName]) -> void:
	for node_name: StringName in nodes:
		delete_node(node_name)



func delete_node(node_name: StringName) -> void:
	var node: RationalGraphNode = get_node(String(node_name))
	if not node or not node.is_slot_enabled_left(0): 
		return
	
	if node.component is Composite:
		var new_children: Array[RationalComponent] = []
		node.component.set_children(new_children)
	
	for con: Dictionary in get_connection_list_from_node(node_name):
		if con.to_node == node_name:
			var parent: RationalComponent = node_get_comp(con.from_node)
			parent.remove_child(node.component)
	
	remove_child(node)
	node.queue_free()


func node_get_comp(node_name: String) -> RationalComponent:
	return get_node(node_name).component if has_node(node_name) else null

func node_is_parented(node: String) -> bool:
	return node_get_parent(node) != null

func node_get_parent(node: String) -> RationalGraphNode:
	for con: Dictionary in get_connection_list_from_node(node):
		if con.to_node == node:
			return get_node(String(con.from_node))
	return null


## Parent node's component adds child nodes's component if possible.
func node_add_child(parent_name: StringName, child_name: StringName) -> void:
	
	var parent: RationalGraphNode = get_node_or_null(String(parent_name))
	var child: RationalGraphNode = get_node_or_null(String(child_name))
	
	if not parent.component.can_parent(child.component):
		show_dialog("Error", "Infinite Recuresion: RationalComponent '%s' can not be in child '%s' node tree.")
		return
	
	if parent.component is Composite:
		var child_to_add: RationalComponent = child.component.duplicate() if active_root.root.has_child(child.component, true) else child.component
		var child_index: int = node_get_index(child)
		
		parent.component.add_child(child_to_add, child_index)
		print("Parent '%s' added child '%s'." % [parent.component, child_to_add])


func update_graph() -> void:
	if updating_graph:
		return
	
	updating_graph = true
	
	clear()
	
	populate_tree()
	
	arrange_graph_nodes()
	
	
	queue_redraw.call_deferred()
	
	updating_graph = false


func populate_tree() -> void:
	if not active_root or not active_root.root: return
	add_node(active_root.root)

## Recursively adds all children.
func add_node(comp: RationalComponent) -> RationalGraphNode:
	var node: RationalGraphNode = RationalGraphNode.new(style, horizontal_layout)
	add_child(node)
	
	node.set_component(comp)
	node.component_children_changed.connect(_on_component_children_changed.bind(node))
	node.dragged.connect(_on_node_dragged, CONNECT_APPEND_SOURCE_OBJECT)
	comp.children_changed.connect(node.component_children_changed.emit)
	
	node.set_slots(comp != active_root.root, comp is Composite)
	
	for child: RationalComponent in comp.get_children():
		var child_node:= add_node(child)
		connect_node(node.name, 0, child_node.name, 0)
	
	return node

func node_get_connected_children(node: RationalGraphNode) -> Array[RationalGraphNode]:
	var result: Array[RationalGraphNode]
	for con: Dictionary in get_connection_list_from_node(node.name):
		if con.from_node == node.name:
			result.push_back(get_node(String(con.to_node)))
	return result


## Only updates child connections.
func update_node_connections(node: RationalGraphNode) -> void:
	for con: Dictionary in get_connection_list_from_node(node.name):
		if con.from_node == node.name:
			disconnect_node(con.from_node, 0, con.to_node, 0)
	
	for child: RationalComponent in node.component.get_children():
		var child_node: RationalGraphNode
		if comp_has_node(child):
			child_node = comp_get_graph_node(child)
		else:
			child_node = add_node(child)
			print("%s creating child node: %s" % [node.component, child])
		connect_node(node.name, 0, child_node.name, 0)


func create_tree_node(comp: RationalComponent, parent: TreeNode = null) -> TreeNode:
	var tree_node: TreeNode = TreeNode.new(comp_get_graph_node(comp), parent)
	for child: RationalComponent in comp.get_children():
		var child_tree_node := create_tree_node(child, tree_node)
		tree_node.children.push_back(child_tree_node)
	return tree_node

func arrange_graph_nodes() -> void:
	if arranging_nodes or not active_root: return
	
	arranging_nodes = true
	
	var tree_node:= create_tree_node(active_root.root)
	tree_node.update_positions(horizontal_layout)
	place_nodes(tree_node)
	
	arranging_nodes = false


func place_nodes(node: TreeNode) -> void:
	node.item.position_offset = Vector2(node.x, node.y)
	for child in node.children:
		place_nodes(child)

func comp_has_node(comp: RationalComponent) -> bool:
	return has_node(comp_get_node_name(comp))

func comp_get_node_name(comp: RationalComponent) -> String:
	return str(comp.get_instance_id())

func comp_get_graph_node(comp: RationalComponent) -> RationalGraphNode:
	return get_node_or_null(comp_get_node_name(comp))


func close_active_root() -> void:
	active_root = null


func clear() -> void:
	clear_connections()
	for child: RationalGraphNode in get_graph_nodes():
		remove_child(child)
		child.queue_free()


func set_active_root(val: RootData) -> void:
		if active_root == val: return
		
		
		if active_root:
			active_root.closed.disconnect(close_active_root)
			graph_states[active_root] = get_graph_state()
		
		
		active_root = val
		
		if active_root:
			active_root.closed.connect(close_active_root)
		
		update_graph()
		restore_graph_state.call_deferred(graph_states.get(active_root, {}))


func place_loose_nodes(components: Array[RationalComponent]) -> void:
	var node_offset: Vector2 = get_graph_rect().end * Vector2(float(horizontal_layout), float(!horizontal_layout))
	var temp_root: Composite = Sequence.new()
	for comp: RationalComponent in components:
		temp_root.add_child(comp)
	
	var node: RationalGraphNode = add_node(temp_root)
	
	var tree_node:= create_tree_node(temp_root)
	tree_node.update_positions(horizontal_layout)
	place_nodes(tree_node)
	delete_node(node.name)
	
	for comp: RationalComponent in components:
		offset_component(comp, node_offset)


func offset_component(comp: RationalComponent, offset: Vector2) -> void:
	comp_get_graph_node(comp).position_offset += offset
	for child in comp.get_children():
		offset_component(child, offset)


func restore_graph_state(state: Dictionary) -> void:
	if state.is_empty(): return
	var is_different_layout: bool = state.get("horizontal", !horizontal_layout) != horizontal_layout
	

	var rect:= get_graph_rect()
	
	var comps: Array[RationalComponent]
	for dict: Dictionary in state.get("nodes", {}).values():
		if dict.has_parent or comp_has_node(dict.comp): continue
		comps.push_back(dict.comp)
	
	
	if is_different_layout:
		place_loose_nodes(comps)
	
	else:
		for comp: RationalComponent in comps:
			add_node(comp)
		
		for comp: RationalComponent in state.get("nodes"):
			var node: RationalGraphNode = comp_get_graph_node(comp)# if comp_has_node(comp) else add_node(comp) 
			node.position_offset = state.nodes[comp].get("position_offset", node.position_offset)
	
	zoom = state.get("zoom", 1.0)
	scroll_offset = state.get("scroll_offset", Vector2.ZERO)
	#print("Graph state restored!")

func get_elbow_connection_line(from_position: Vector2, to_position: Vector2) -> PackedVector2Array:
	var points: PackedVector2Array
	
	points.push_back(from_position)
	
	var mid_position := ((to_position + from_position) / 2).round()
	if horizontal_layout:
		points.push_back(Vector2(mid_position.x, from_position.y))
		points.push_back(Vector2(mid_position.x, to_position.y))
	else:
		points.push_back(Vector2(from_position.x, mid_position.y))
		points.push_back(Vector2(to_position.x, mid_position.y))

	points.push_back(to_position)

	return points

func get_graph_nodes() -> Array[RationalGraphNode]:
	var result: Array[RationalGraphNode]
	for child in get_children():
		if child is RationalGraphNode:
			result.push_back(child)
	return result

## Calculates node position based on current scroll and zoom.
func get_node_position(node: GraphNode) -> Vector2:
	return node.position_offset * zoom - scroll_offset

func get_graph_state() -> Dictionary:
	
	var state: Dictionary = {
		zoom = zoom,
		scroll_offset = scroll_offset,
		horizontal = horizontal_layout,
		#preview = preview,
		nodes = {},
	}
	
	for node: RationalGraphNode in get_graph_nodes():
		state.nodes[node.component] = {
			position_offset = node.position_offset,
			comp = node.component,
			has_parent = node_is_parented(node.name),
		}
	
	return state


func _on_root_reloaded() -> void:
	update_graph()


func get_port_range_squared() -> float:
	return (PORT_RANGE/ zoom)  ** 2

func _is_in_input_hotzone(in_node: Object, in_port: int, mouse_position: Vector2) -> bool:
	in_node.is_left_port_hovered = (mouse_position).distance_squared_to(get_node_port_position(in_node, false)) < get_port_range_squared()
	return in_node.is_left_port_hovered

func _is_in_output_hotzone(in_node: Object, in_port: int, mouse_position: Vector2) -> bool:
	in_node.is_right_port_hovered = mouse_position.distance_squared_to(get_node_port_position(in_node, true) ) < get_port_range_squared()
	return in_node.is_right_port_hovered
	
func get_node_port_position(node: GraphNode, is_output: bool) -> Vector2:
	if is_output:
		if horizontal_layout:
			return node.position_offset + Vector2(node.size.x, node.size.y / 2.0) - scroll_offset / zoom
		else:
			return node.position_offset + Vector2(node.size.x / 2.0, node.size.y) - scroll_offset / zoom
	elif horizontal_layout:
		return node.position_offset + Vector2(0, node.size.y / 2.0) - scroll_offset / zoom
	
	return node.position_offset + Vector2(node.size.x / 2.0, 0) - scroll_offset / zoom


func show_dialog(title: String, message: String, buttons:PackedStringArray = PackedStringArray(["OK"]), callable: Callable = Callable().unbind(1)) -> void:
	DisplayServer.dialog_show(title, message, buttons, callable)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		if is_dragging_connection:
			queue_redraw()
	
	if not event.is_pressed() or event.is_echo():
		return
	
	if event is InputEventMouseButton:
		if not is_dragging_connection and event.button_index == MOUSE_BUTTON_RIGHT:
			if disconnect_hovered_port():
				return
			
			open_create_popup(get_viewport().position + Vector2i(event.global_position))

	if event is InputEventKey:
		match event.keycode:
			KEY_R:
				print("RootData: %s" % active_root, )
				if not active_root: return
				var node: RationalGraphNode = comp_get_graph_node(active_root.root)
				var path:= node.component.resource_path if node and node.component else ""
				print("Root Graph Node: %s" % (node))
				print("Root Graph Node Component: %s" % (node.component))
				print("Component Path: '%s'" % path)
				
			KEY_T:
				active_root.root.print_tree_pretty()
				#active_root.sync_path()

func _unhandled_input(event: InputEvent) -> void:
	return
	#if not event.is_pressed() or event.is_echo():
		#return
	
	#if event is InputEventMouseButton:
		#if event.button_index == MOUSE_BUTTON_RIGHT:
			#open_create_popup(get_viewport().position + Vector2i(event.global_position))


func _draw() -> void:
	
	const LINE_COLOR := Color.WHITE
	const CONNECTION_LINE_COLOR := Color.LIGHT_GRAY
	const BASE_LINE_SIZE: float = 7.0
	
	#var circle_size: float = max(4, 8 * zoom)
	#var progress_shift: float = PROGRESS_SHIFT * zoom
	var line_width: float = BASE_LINE_SIZE * zoom

	var connections := get_connection_list()
	for c: Dictionary in connections:
		var from_node: StringName = c.from_node
		var to_node: StringName = c.to_node
		
		
		var from: RationalGraphNode = get_node(String(from_node))
		var to: RationalGraphNode = get_node(String(to_node))
		
		var output_port_position: Vector2 = from.position + from.get_custom_output_port_position(horizontal_layout) * zoom
		var input_port_position: Vector2 = to.position + to.get_custom_input_port_position(horizontal_layout) * zoom
		
		var line := get_elbow_connection_line(output_port_position, input_port_position)
		
		draw_polyline(line, LINE_COLOR, line_width, true)
	
	if is_dragging_connection:
		var line := get_elbow_connection_line(connection_start_position, get_local_mouse_position())
		draw_polyline(line, CONNECTION_LINE_COLOR, line_width, true)

func _on_component_children_changed(node: RationalGraphNode) -> void:
	update_node_connections(node)

func _get_connection_line(from_position: Vector2, to_position: Vector2) -> PackedVector2Array:
	const VECS: PackedVector2Array = [Vector2(-9999999, -9999999), Vector2(-9999999, -9999999)]
	return VECS


func get_selected_nodes() -> Array[RationalGraphNode]:
	var result: Array[RationalGraphNode]
	for node: RationalGraphNode in get_graph_nodes():
		if not node.selected: continue
		result.push_back(node)
	return result


func get_selected_components() -> Array[RationalComponent]:
	var result: Array[RationalComponent]
	for node: RationalGraphNode in get_selected_nodes():
		result.push_back(node.component)
	return result


func get_graph_rect() -> Rect2:
	var rect: Rect2 = Rect2()
	for node: RationalGraphNode in get_graph_nodes():
		
		if not rect:
			rect.position = node.position_offset
			rect.size = node.size
			continue
		
		rect.position.x = minf(node.position_offset.x, rect.position.x)
		rect.position.y = minf(node.position_offset.y, rect.position.y)
		rect.end.x = maxf(node.position_offset.x + node.size.x, rect.end.x)
		rect.end.y = maxf(node.position_offset.y + node.size.y, rect.end.y)
	
	return rect


func _on_tree_display_selected_items_changed(items: Array[RationalComponent]) -> void:
	block_selection_signal = true
	printt("SELECTED ITEMS: ", items)
	for node: RationalGraphNode in get_graph_nodes():
		node.selected = node.component in items
	block_selection_signal = false


func get_hovered_port_node() -> RationalGraphNode:
	for node: RationalGraphNode in get_graph_nodes():
		if node.is_left_port_hovered or node.is_right_port_hovered:
			return node
	return null

func is_hovering_port() -> bool:
	for node in get_graph_nodes():
		if node.is_left_port_hovered or node.is_right_port_hovered:
			return true
	return false

## Returns true if hovering port.
func disconnect_hovered_port() -> bool:
	var node: RationalGraphNode = get_hovered_port_node()
	
	if not node:
		return false
	
	for con: Dictionary in get_connection_list_from_node(node.name):
		if node.is_left_port_hovered and con.to_node == node.name:
			var parent: RationalGraphNode = get_node(str(con.from_node))
			parent.component.remove_child(node.component)
		
		if node.is_right_port_hovered and con.from_node == node.name:
			var child: RationalGraphNode = get_node(str(con.to_node))
			node.component.remove_child(child.component)
	
	return true

func toggle_layout() -> void:
	horizontal_layout = !horizontal_layout

func update_layout_button() -> void:
	layout_button.icon = VERTICAL_LAYOUT_ICON if horizontal_layout else HORIZONTAL_LAYOUT_ICON
	layout_button.tooltip_text = "Switch to Vertical layout" if horizontal_layout else "Switch to Horizontal layout"
