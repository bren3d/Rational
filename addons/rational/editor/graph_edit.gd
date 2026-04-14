@tool
extends GraphEdit

const Util := preload("../util.gd")

const EditorStyle = preload("editor_style.gd")
const RationalGraphNode := preload("graph_node.gd")
const CreatePopup = preload("component_dialog.gd") 
const Menu := preload("popup_menu.gd")
const ActionHandle := preload("action_handle.gd")
const Selection:= preload("selection.gd")

const PROGRESS_SHIFT: int = 50
const PORT_RANGE: float = 20
const CONNECTING_SNAP_MOD_INCREASE: float = 2.5
const DUPLICATE_OFFSET: Vector2 = Vector2(25.0, 25.0)

@export var popup: CreatePopup
@export var tree_display: Tree

var style: EditorStyle
var layout_button: Button

var menu: Menu

var updating_graph: bool = false
var arranging_nodes: bool = false
var restoring_state: bool = false

var horizontal_layout: bool = false:
	set(value):
		if updating_graph or arranging_nodes or restoring_state:
			return
		if horizontal_layout == value:
			return
		horizontal_layout = value
		update_layout_button()
		save_current_orphans()
		arrange_graph_nodes()
		queue_redraw.call_deferred()

var active_root: RootData: set = set_active_root

var graph_states: Dictionary[RootData, Dictionary]

var is_dragging_connection: bool = false
var connection_start_position: Vector2
var connecting_node: RationalGraphNode
var connecting_output: bool = false

var create_popup_start_position: Vector2

var is_moving_node: bool = false

var is_restoring_state: bool = false

var reset_dragged_nodes: bool = false

var shortcuts: Dictionary[Shortcut, Callable]

var selection: Selection
var action_handle: ActionHandle

var undo_redo: EditorUndoRedoManager

## Node selected with right click when creating a menu.
var selected_node: RationalGraphNode

func _ready() -> void:
	selection = Util.get_selection()
	selection.selection_changed.connect(_on_selection_changed)
	style = EditorStyle.new()
	
	custom_minimum_size = Vector2(200, 200) * EditorInterface.get_editor_scale()
	
	layout_button = get_menu_hbox().get_child(-1).duplicate(0)
	layout_button.show()
	layout_button.toggle_mode = false
	update_layout_button()
	get_menu_hbox().add_child(layout_button)
	layout_button.pressed.connect(toggle_layout)
	
	connection_drag_started.connect(_on_connection_drag_started)
	connection_request.connect(_on_connection_request)
	connection_drag_ended.connect(_on_connection_drag_ended)
	
	cut_nodes_request.connect(cut)
	
	copy_nodes_request.connect(copy)
	paste_nodes_request.connect(paste)
	duplicate_nodes_request.connect(duplicate_components)
	delete_nodes_request.connect(_on_delete_nodes_request)
	
	node_selected.connect(_on_node_selected)
	node_deselected.connect(_on_node_deselected)
	
	begin_node_move.connect(_on_begin_node_move)
	end_node_move.connect(_on_end_node_move)
	
	popup_request.connect(_on_popup_request)
	
	action_handle = Util.get_action_handle()
	action_handle.add_component.connect(undo_redo_add_comp_node)
	action_handle.remove_component.connect(undo_redo_remove_comp_node)
	
	undo_redo = Util.get_undo_redo()
	
	menu = Menu.new()
	add_child(menu)
	menu.id_pressed.connect(_on_menu_id_pressed)
	menu.popup_hide.connect(clear_selected_node, CONNECT_DEFERRED)
	
	init_shortcuts()


func _on_add_component(comp: RationalComponent) -> void:
	var node:= undo_redo_add_comp_node(comp)
	place_new_node.call_deferred(node)

func place_new_node(node: RationalGraphNode) -> void:
	if not node: return
	# TODO

#region Menu

func _on_popup_request(at_position: Vector2) -> void:
	if is_moving_node:
		cancel_drag()
		return
	
	if disconnect_hovered_port():
		return
	
	
	selected_node = get_node_at_position(at_position)
	
	if selected_node:
		selected_node.selected = true
		
		if not Input.is_key_pressed(KEY_SHIFT) and not Input.is_key_pressed(KEY_CTRL):
			set_selected(selected_node)
	
	if selected_node or Input.is_key_pressed(KEY_SHIFT):
		menu.popup_at(get_menu_options(selected_node), get_screen_position() + at_position)
		return
	
	show_quick_create_popup(get_screen_position() + at_position)

func get_menu_options(node: RationalGraphNode = null) -> int:
	var selected_nodes:= get_selected_nodes()
	
	if not node:
		return (Menu.ITEMS_HERE ^ (Menu.ITEM_PASTE_HERE * int(not action_handle.has_clipboard()))) \
				^ (Menu.ITEM_MOVE_NODE_HERE * int(selected_nodes.is_empty()))
	
	assert(not selected_nodes.is_empty())
	var options: int = Menu.ITEMS_DEFAULT | (Menu.ITEM_PASTE * int(action_handle.has_clipboard()))
	
	if 1 < selected_nodes.size():
		options &= ~(Menu.ITEM_SAVE_AS_ROOT | Menu.ITEM_ADD_CHILD)
	elif selected_nodes.size() == 1:
		if not selected_nodes[0].component is Composite:
			options &= ~Menu.ITEM_ADD_CHILD
	
	return options

func _on_menu_id_pressed(id: int) -> void:
	match id:
		Menu.ITEM_ADD_CHILD:
			add_child_component()
		Menu.ITEM_INSTANTIATE_NODE:
			instantiate_child()
		Menu.ITEM_CUT:
			cut()
		Menu.ITEM_COPY:
			copy()
		Menu.ITEM_PASTE:
			paste()
		Menu.ITEM_PASTE_HERE:
			paste_here()
		Menu.ITEM_DUPLICATE:
			duplicate_components()
		Menu.ITEM_RENAME:
			rename()
		Menu.ITEM_CHANGE_TYPE:
			change_type()
		Menu.ITEM_SAVE_AS_ROOT:
			save_as_root()
		Menu.ITEM_DOCUMENTATION:
			open_documentation()
		Menu.ITEM_DELETE:
			delete()
		Menu.ITEM_ADD_NODE_HERE:
			pass
		Menu.ITEM_INSTANTIATE_NODE_HERE:
			pass
		Menu.ITEM_PASTE_HERE:
			paste_here()
		Menu.ITEM_MOVE_NODE_HERE:
			move_nodes_here(get_selected_nodes())
		Menu.ITEM_PASTE_AS_SIBLING:
			paste_as_sibling()


#endregion Menu


#region shortcuts

func init_shortcuts() -> void:
	shortcuts[Util.get_shortcut(&"toggle_grid")] = toggle_grid
	shortcuts[Util.get_shortcut(&"use_grid_snap")] = toggle_snap
	shortcuts[Util.get_shortcut(&"frame_selection")] = frame_selection
	shortcuts[Util.get_shortcut(&"center_selection")] = center_selection
	shortcuts[Util.get_shortcut(&"zoom_minus")] = zoom_out
	shortcuts[Util.get_shortcut(&"zoom_plus")] = zoom_in
	shortcuts[Util.get_shortcut(&"cancel_transform")] = cancel_drag
	
	for percent_str: String in ["3.125", "6.25", "12.5", "25", "50", "100", "200", "400"]: # , "800", "1600" Can't zoom that much.
		shortcuts[Util.get_shortcut("zoom_%s_percent" % percent_str)] = set_zoom.bind(float(percent_str.to_float())/100.0)
	
	
	shortcuts[Util.get_shortcut(&"rename")] = rename
	shortcuts[Util.get_shortcut(&"change_type")] = change_type
	shortcuts[Util.get_shortcut(&"save_as_root")] = save_as_root
	
	shortcuts.erase(null)

func move_nodes_here(nodes: Array[RationalGraphNode], skip_action: bool = true) -> void:
	if not nodes: return
	var offset_delta: Vector2 = local_to_offset(Vector2(menu.position) - get_screen_position()) - nodes_get_rect(nodes).get_center()
	
	for node: RationalGraphNode in nodes:
		if skip_action:
			move_component(node.component, node.position_offset + offset_delta)
			continue
		
		action_handle.create_action("Move Component(s) to Position")
		undo_redo.add_undo_method(self, &"move_component", node.component, node.position_offset)
		undo_redo.add_do_method(self, &"move_component", node.component, node.position_offset + offset_delta)
		action_handle.commit(true)


func select_and_center(comp: RationalComponent) -> void:
	if not comp or not comp_has_node(comp): return
	set_selected(comp_get_graph_node(comp))
	center_selection()


func instantiate_child() -> void:
	action_handle.prompt_instantiate_child(get_selected_comp())

func add_child_component() -> void:
	action_handle.prompt_add_child(get_selected_comp())

func cut() -> void:
	if is_dragging_connection: return
	action_handle.cut()

func delete() -> void:
	if is_dragging_connection: return
	action_handle.delete()

func copy() -> void:
	if is_dragging_connection: return
	action_handle.copy()

func paste() -> void:
	if is_dragging_connection or not action_handle.can_paste(): 
		return
	
	if has_selected_node():
		action_handle.paste(get_selected_comp())
		return
	
	paste_here()

func paste_as_sibling() -> void:
	var sibling: RationalComponent = get_selected_comp()
	action_handle.paste_as_sibling(comp_get_parent(sibling), sibling, )

func paste_here() -> void:
	if is_dragging_connection or not action_handle.can_paste(): 
		return
	
	var orphan_offset: Vector2 = nodes_get_rect(get_graph_nodes()).end * get_layout_dir()
	var components: Array[RationalComponent] = action_handle.get_top_clipboard_components().duplicate_deep(Resource.DEEP_DUPLICATE_INTERNAL)
	
	var nodes: Array[RationalGraphNode]
	for comp: RationalComponent in components:
		action_handle.create_action("Paste Component(s)", UndoRedo.MERGE_DISABLE)
		nodes.push_back(undo_redo_add_comp_node(comp))
		action_handle.commit(false)
	
	place_orphans.call_deferred(action_handle.get_clipboard(), orphan_offset)
	move_nodes_here.call_deferred(nodes, false)


func duplicate_components() -> void:
	if is_dragging_connection or not has_selected_node():
		return
	
	action_handle.duplicate()


## Adds actions unparent the comp as well as to remove/add the node associated with [param comp].
func undo_redo_remove_comp(comp: RationalComponent) -> void:
	if not comp or comp == get_root_component(): return
	undo_redo_remove_comp_node(comp)
	var parent: RationalComponent = comp_get_parent(comp)
	if parent:
		undo_redo.add_undo_method(parent, &"add_child", comp, parent.get_child_index(comp))
		undo_redo.add_do_method(parent, &"remove_child", comp)

## Adds all children recursively.
func undo_redo_add_comp_node(comp: RationalComponent) -> RationalGraphNode:
	if not comp: return null
	
	var node: RationalGraphNode = add_node(comp, false, false)
	undo_redo.add_undo_method(self, &"remove_child", node)
	undo_redo.add_do_reference(node)
	undo_redo.add_do_method(self, &"add_child", node)
	
	for child: RationalComponent in comp.get_children(true):
		var child_node: RationalGraphNode = add_node(child, false, false)
		undo_redo.add_undo_method(self, &"remove_child", child_node)
		undo_redo.add_do_reference(child_node)
		undo_redo.add_do_method(self, &"add_child", child_node)
		
	return node

## Adds actions to remove/add the node associated with [param comp].
func undo_redo_remove_comp_node(comp: RationalComponent) -> void:
	if not comp or not comp_has_node(comp) or comp == get_root_component(): return
	var node: RationalGraphNode = comp_get_graph_node(comp)
	
	undo_redo.add_undo_reference(node)
	undo_redo.add_undo_method(self, &"add_child", node)
	undo_redo.add_do_method(self, &"remove_child", node)
	


## Only prompts to change type. Does not change any scripts.
func change_type() -> void:
	if not is_dragging_connection and has_selected_node():
		action_handle.change_type(get_selected_comp())

func save_as_root() -> void:
	if is_dragging_connection: return
	pass

func rename() -> void:
	if not is_dragging_connection and has_selected_node():
		get_selected().rename()

func zoom_in() -> void:
	zoom *= zoom_step

func zoom_out() -> void:
	zoom /= zoom_step

func center_selection() -> void:
	if has_selected_node(): 
		scroll_offset = nodes_get_rect(get_selected_nodes()).get_center() * zoom - size / 2.0

func frame_selection() -> void:
	if not has_selected_node(): return
	frame_rect(nodes_get_rect(get_selected_nodes()))

func frame_rect(rect: Rect2) -> void:
	zoom = minf(size.x/rect.size.x, size.y/rect.size.y)/ zoom_step
	scroll_offset = rect.get_center() * zoom - size / 2.0

func toggle_grid() -> void:
	show_grid = !show_grid

func toggle_snap() -> void:
	snapping_enabled = !snapping_enabled

func open_documentation() -> void:
	if not is_dragging_connection and has_selected_node():
		EditorInterface.get_script_editor().goto_help("class_name:%s" % get_selected().get_component_class())


func _shortcut_input(event: InputEvent) -> void:
	if not event.is_pressed() or event.is_echo() or not has_focus():
		return
	
	for sc: Shortcut in shortcuts:
		if sc.matches_event(event):
			printt("GraphEdit Calling shortcut: %s " % sc.get_as_text())
			
			accept_event()
			shortcuts[sc].call()
			return

#endregion shortcuts

func get_node_at_position(at_position: Vector2) -> RationalGraphNode:
	#if not get_rect().has_point(at_position):
		#return null
	for node: RationalGraphNode in get_graph_nodes():
		if node.get_rect().has_point(at_position):
			return node
	return null



## Sets [param node].component's index equal to [param node]'s index on the graph.
func update_component_index(node: RationalGraphNode) -> void:
	var parent: RationalGraphNode = node_get_parent(node.name)
	
	if not parent:
		return
	
	var node_idx: int = node_get_index(node)
	#print("Setting node index: %s" % node_idx)
	parent.component.move_child(node.component, node_idx)


func node_get_index(node: RationalGraphNode) -> int:
	var parent: RationalGraphNode = node_get_parent(node.name)
	
	if not parent:
		return -1
	
	return node_get_children_sorted(parent).find(node)

func node_get_children_sorted(parent: RationalGraphNode) -> Array[RationalGraphNode]:
	var children : Array[RationalGraphNode] = node_get_children(parent)
	children.sort_custom(sort_position)
	return children

func sort_position(node_a: RationalGraphNode, node_b: RationalGraphNode) -> bool:
	return node_a.position_offset.y < node_b.position_offset.y if horizontal_layout else node_a.position_offset.x < node_b.position_offset.x

func show_quick_create_popup(at_position: Vector2) -> void:
	if active_root:
		popup.open(at_position, create_component.bind(at_position - global_position))


func create_component(_class: StringName, at_position: Vector2 = Vector2.ZERO) -> void:
	if not _class or not Util.class_is_valid(_class): return
	var comp: RationalComponent = Util.instantiate_class(_class)
	var offset: Vector2 = local_to_offset(at_position) if at_position else Vector2.ZERO
	
	action_handle.create_action("Create Component")
	var node: RationalGraphNode = undo_redo_add_comp_node(comp)
	place_node_at(node, offset)
	action_handle.commit(true)
	
	print_rich("[color=green]Node Created: %s[/color]" % comp)


func place_node_at(node: RationalGraphNode, offset: Vector2) -> void:
	# TODO: Add check for collision and adjust
	node.position_offset = offset

func _on_connection_drag_started(from_node: StringName, from_port: int, is_output: bool) -> void:
	#print("Connection drag started")
	connecting_node = get_node(String(from_node))
	connecting_output = is_output
	connection_start_position = get_node_port_position(connecting_node, is_output) * zoom
	is_dragging_connection = true
	accept_event()
	queue_redraw()

func _on_connection_drag_ended() -> void:
	#print("Connection drag ended")
	connecting_node = null
	is_dragging_connection = false
	queue_redraw()

func _on_connection_request(from_node: StringName, from_port: int, to_node: StringName, to_port: int) -> void:
	if not from_port == to_port and from_port == 0:
		printerr("Attempting to connect graph node port != 0.")
		return
	
	#print("CONNECTION REQUEST CALLED")
	var current_parent: RationalGraphNode = node_get_parent(to_node)
	var current_parent_comp: RationalComponent = current_parent.component if current_parent else null
	action_handle.reparent_item(node_get_comp(to_node), node_get_comp(from_node), current_parent_comp, UndoRedo.MERGE_DISABLE)


func _on_delete_nodes_request(nodes: Array[StringName]) -> void:
	if is_dragging_connection: return
	delete()

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
	var current_parent:= node_get_parent(child_name)
	
	if current_parent:
		current_parent.component.remove_child(child.component)
	
	if not parent.component.can_parent(child.component):
		show_dialog("Error", "'%s' cannot be child of '%s'" % [child.component, parent.component])
		return
	
	if parent.component is Composite:
		var child_to_add: RationalComponent = child.component
		var child_index: int = node_get_index(child)
		
		parent.component.add_child(child_to_add, child_index)
		print("Parent '%s' added child '%s'." % [parent.component, child_to_add])


func update_graph() -> void:
	if active_root and not active_root.is_loaded():
		active_root.loaded.connect(update_graph, CONNECT_ONE_SHOT)
		return
	
	if updating_graph:
		return
	
	updating_graph = true
	
	clear()
	
	if get_root_component():
	
		populate_tree()
		
		if can_restore_state():
			restore_root_state()
		else:
			arrange_graph_nodes()
		
		queue_redraw.call_deferred()
	
	updating_graph = false


func populate_tree() -> void:
	add_node(get_root_component())
	
	for comp: RationalComponent in get_active_root_orphans():
		add_node(comp)
	

## Recursively adds all children.
func add_node(comp: RationalComponent, add_child_immediately: bool = true, recursive: bool = true) -> RationalGraphNode:
	if not comp: return
	
	if comp_has_node(comp):
		return comp_get_graph_node(comp)
	
	var node: RationalGraphNode = RationalGraphNode.new(style, horizontal_layout)
	
	if add_child_immediately:
		add_child(node)
	
	node.set_component(comp)
	node.component_children_changed.connect(_on_component_children_changed, CONNECT_APPEND_SOURCE_OBJECT | CONNECT_DEFERRED)
	node.dragged.connect(_on_node_dragged, CONNECT_APPEND_SOURCE_OBJECT)
	node.position_offset_changed.connect(_on_node_position_offset_changed, CONNECT_APPEND_SOURCE_OBJECT | CONNECT_DEFERRED)
	node.resized.connect(queue_redraw, CONNECT_DEFERRED)
	node.slot_sizes_changed
	
	node.set_slots(comp != get_root_component(), comp is Composite)
	
	if recursive:
		for child: RationalComponent in comp.get_children():
			var child_node:= add_node(child)
			connect_node(node.name, 0, child_node.name, 0)
	
	return node




func comp_get_parent(comp: RationalComponent) -> RationalComponent:
	if not comp: return null
	for graph_comp: RationalComponent in get_components():
		if graph_comp and graph_comp.has_child(comp, false):
			return graph_comp
	return null

func delete_node(node_name: String) -> void:
	if not has_node(node_name): return
	var node: RationalGraphNode = get_node(node_name)
	
	if node.component == get_root_component():
		return
	
	for con: Dictionary in get_connection_list_from_node(node_name):
		disconnect_node(con.from_node, 0, con.to_node, 0)
		if con.to_node == node_name:
			var parent: RationalComponent = node_get_comp(con.from_node)
			parent.remove_child(node.component)
	
	
	
	remove_child(node)
	node.queue_free()


## Adds a new/existing component.
func add_component(comp: RationalComponent) -> void:
	var node: RationalGraphNode = add_node(comp)

## Removes component from the graph entirely. Looks for parent component to remove.
func remove_component(comp: RationalComponent) -> void:
	if comp == get_root_component(): return
	
	var node:= comp_get_graph_node(comp)
	if node:
		remove_child(node)
		node.queue_free()


func node_get_children(node: RationalGraphNode) -> Array[RationalGraphNode]:
	if not node: return []
	var result: Array[RationalGraphNode]
	for con: Dictionary in get_connection_list_from_node(node.name):
		if con.from_node == node.name and has_node(String(con.to_node)):
			result.push_back(get_node(String(con.to_node)))
	return result


## Only updates child connections.
func update_node_connections(node: RationalGraphNode) -> void:
	for child_node: RationalGraphNode in node_get_children(node):
		if not child_node or node.component.has_child(child_node.component): continue
		disconnect_node(node.name, 0, child_node.name, 0)
	
	for child: RationalComponent in node.component.get_children():
		if not comp_has_node(child):
			var child_node:= add_node(child)
			parent_place_child(child_node, node)
			
		if not is_node_connected(node.name, 0, comp_get_node_name(child), 0):
			connect_node(node.name, 0, comp_get_node_name(child), 0)

func parent_place_child(child: RationalGraphNode, parent: RationalGraphNode) -> void:
	return
	assert(child.component in parent.component.get_children())
	var sibling_axis: int = int(horizontal_layout)
	var level_axis: int = abs(sibling_axis - 1)
	print("sibling_axis: %s | level_axis: %s" %[sibling_axis, level_axis])
	
	child.position_offset[level_axis] = parent.position_offset[level_axis] + parent.size[level_axis] + TreeNode.LEVEL_SIZE

	
	if parent.component.get_child_count() <= 1:
		child.position_offset[sibling_axis] = parent.position_offset[sibling_axis] + (parent.size - child.size)[sibling_axis]/2.0
		print("Parent: %s | Child: %s" % [parent.get_rect(), child.get_rect()])
		return
	
	var idx: int = parent.component.get_child_index(child.component)
	assert(-1 < idx and idx < parent.component.get_child_count(), "OOB child index from 'get_child_index' function." )
	var children: Array[RationalGraphNode] = node_get_children_sorted(parent)
	children.erase(child)
	if idx == 0:
		child.position_offset[sibling_axis] = children[0].position_offset[sibling_axis] - TreeNode.LATERAL_SIZE
	elif idx >= parent.component.get_child_count() - 1:
		child.position_offset[sibling_axis] = children[-1].position_offset[sibling_axis] + children[-1].size[sibling_axis] + TreeNode.LATERAL_SIZE
	else:
		child.position_offset[sibling_axis] = lerpf(children[idx-1].position_offset[sibling_axis] + children[idx-1].size[sibling_axis]
				, children[idx+1].position_offset[sibling_axis], 0.5)
	
	print("Parent: %s | Child: %s" % [parent.get_rect(), child.get_rect()])

func get_layout_dir() -> Vector2:
	return Vector2.ONE * Vector2(float(horizontal_layout), float(!horizontal_layout))

func create_tree_node(comp: RationalComponent, parent: TreeNode = null) -> TreeNode:
	var tree_node: TreeNode = TreeNode.new(comp_get_graph_node(comp), parent)
	for child: RationalComponent in comp.get_children():
		var child_tree_node := create_tree_node(child, tree_node)
		tree_node.children.push_back(child_tree_node)
	return tree_node

func arrange_graph_nodes() -> void:
	if arranging_nodes or not active_root: return
	
	arranging_nodes = true
	
	propagate_call(&"set_horizontal", [horizontal_layout])
	
	var tree_node:= create_tree_node(get_root_component())
	tree_node.calculate_tree()
	
	#tree_node.update_positions(horizontal_layout)
	place_nodes(tree_node)
	
	#var offset: Vector2 = get_tree_end(tree_node) * Vector2(float(horizontal_layout), float(!horizontal_layout))
	#place_orphans(get_active_root_orphans(), offset)
	
	arranging_nodes = false


#func arrange_subtree(subtree_root: RationalGraphNode) -> void:
	#if arranging_nodes or not subtree_root: return
	#arranging_nodes = true
	#var tree_node:= create_tree_node(subtree_root.component)
	#arranging_nodes = false


func place_nodes(node: TreeNode) -> void:
	node.item.position_offset = node.get_position() # Vector2(node.x, node.y)
	for child in node.children:
		place_nodes(child)

func get_tree_rect(node: TreeNode) -> Rect2:
	var rect: Rect2 = Rect2(node.item.position_offset, node.item.size)
	for child in node.children:
		rect = rect.merge(get_tree_rect(child))
	return rect

func get_tree_end(tree_node: TreeNode) -> float:
	var result: float = tree_node.x + tree_node.item.layout_size
	for child in tree_node.children:
		result = maxf(result, get_tree_end(child))
	return result

func comp_is_orphan(comp: RationalComponent) -> bool:
	return get_root_component() and not (get_root_component() == comp or get_root_component().has_child(comp, true))

func get_orphan_offset(tree_node: TreeNode) -> Vector2:
	return get_tree_rect(tree_node).end * Vector2(float(horizontal_layout), float(!horizontal_layout))

func place_orphans(components: Array[RationalComponent], offset: Vector2 = Vector2.ZERO) -> void:
	var temp_root: Composite = Sequence.new()
	var node: RationalGraphNode = add_node(temp_root)
	for comp: RationalComponent in components:
		temp_root.add_child(comp)
	
	var tree_node:= create_tree_node(temp_root)
	tree_node.update_positions(horizontal_layout)
	place_nodes(tree_node)
	delete_node(node.name)
	
	for comp: RationalComponent in components:
		comp_set_offset(comp, offset)


func comp_set_offset(comp: RationalComponent, offset: Vector2) -> void:
	comp_get_graph_node(comp).position_offset += offset
	for child in comp.get_children():
		comp_set_offset(child, offset)

func comp_has_node(comp: RationalComponent) -> bool:
	return has_node(comp_get_node_name(comp))

func comp_get_node_name(comp: RationalComponent) -> String:
	return str(comp.get_instance_id())

func comp_get_graph_node(comp: RationalComponent) -> RationalGraphNode:
	return get_node_or_null(comp_get_node_name(comp))


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

func _on_root_data_closed(data: RootData) -> void:
	pass

func close_active_root() -> void:
	graph_states.erase(active_root)

	active_root = null


func get_graph_state() -> Dictionary:
	var node_data: Dictionary
	for node: RationalGraphNode in get_graph_nodes():
		node_data[node.component] = {
			position_offset = node.position_offset,
			comp = node.component,
			}
	
	return {
		zoom = zoom,
		scroll_offset = scroll_offset,
		horizontal = horizontal_layout,
		orphans = get_orphan_components(),
		nodes = node_data,
	}


func restore_graph_state(state: Dictionary) -> void:
	if state.is_empty() or restoring_state: return
	
	restoring_state = true
	
	var is_different_layout: bool = state.get("horizontal", !horizontal_layout) != horizontal_layout
	
	zoom = state.get("zoom", 1.0)
	scroll_offset = state.get("scroll_offset", Vector2.ZERO)
	
	for node: RationalGraphNode in get_graph_nodes():
		node.position_offset = state.get("nodes", {}).get(node.component, {}).get("position_offset", node.position_offset)
	
	restoring_state = false

func restore_root_state() -> void:
	restore_graph_state(graph_states.get(active_root, {}))

func can_restore_state() -> bool:
	return active_root and graph_states.has(active_root)

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

## Returns all RationalGraphNode children shown on graph.
func get_graph_nodes() -> Array[RationalGraphNode]:
	var result: Array[RationalGraphNode]
	for child in get_children():
		if child is RationalGraphNode:
			result.push_back(child)
	return result

## Returns all RationalGraphNode children not connected to the root.
func get_orphan_nodes() -> Array[RationalGraphNode]:
	var result: Array[RationalGraphNode]
	for node: RationalGraphNode in get_graph_nodes():
		if node.component == get_root_component() or node_is_parented(node.name): continue
		result.push_back(node)
	return result

## Returns all components shown on graph.
func get_components() -> Array[RationalComponent]:
	var result: Array[RationalComponent]
	for node in get_graph_nodes():
		result.push_back(node.component)
	return result


func get_orphan_components() -> Array[RationalComponent]:
	var result: Array[RationalComponent]
	for node: RationalGraphNode in get_orphan_nodes():
		if get_root_component().has_child(node.component, true): continue
		result.push_back(node.component)
	return result

func get_active_root_orphans() -> Array[RationalComponent]:
	var result: Array[RationalComponent]
	for orphan: RationalComponent in graph_states.get(active_root, {}).get("orphans", []):
		result.push_back(orphan)
	return result

func save_current_orphans() -> void:
	if not active_root: return
	graph_states.get_or_add(active_root, {})["orphans"] = get_orphan_components()

func get_port_range_squared(mod: float = 1.0) -> float:
	return (mod * PORT_RANGE)  ** 2

func _is_in_input_hotzone(in_node: Object, in_port: int, mouse_position: Vector2) -> bool:
	in_node.is_left_port_hovered = (not is_dragging_connection or (connecting_output and is_connection_valid(connecting_node, in_node))) and 	\
		(mouse_position).distance_squared_to(get_node_port_position(in_node, false)) < 		\
		get_port_range_squared(1.0 + CONNECTING_SNAP_MOD_INCREASE * float(is_dragging_connection))
	return in_node.is_left_port_hovered

func _is_in_output_hotzone(in_node: Object, in_port: int, mouse_position: Vector2) -> bool:
	in_node.is_right_port_hovered = (not is_dragging_connection or (not connecting_output and is_connection_valid(in_node, connecting_node))) and 	\
		mouse_position.distance_squared_to(get_node_port_position(in_node, true) ) < 			\
		get_port_range_squared(1.0 + CONNECTING_SNAP_MOD_INCREASE * float(is_dragging_connection))
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
		if event.button_index == MOUSE_BUTTON_LEFT and event.double_click:
			var node: RationalGraphNode = get_selected()
			if node and node.get_titlebar_rect().has_point(event.position):
				accept_event()
				node.rename()
	
	
	elif event is InputEventKey:
		match event.keycode:
			
			KEY_R:
				printt(Rect2(scroll_offset/zoom, size/zoom))
			
			KEY_T:
				active_root.root.print_tree_pretty()
			
			KEY_L:
				var focus_owner: Control = get_viewport().gui_get_focus_owner()
				print(focus_owner.component if focus_owner is RationalGraphNode else focus_owner)
			
			KEY_C:
				print(action_handle.get_clipboard(false))
			
			KEY_B when event.shift_pressed:
					for child in get_children():
						if not child is GraphFrame: continue
						remove_child(child)
						child.free()
			KEY_B:
					create_frame()
			

func create_frame() -> GraphFrame:
	var gf: GraphFrame = GraphFrame.new()
	gf.autoshrink_enabled = false
	#gf.selectable = false
	gf.resizable = true
	gf.title = "RationalFrame"
	add_child(gf)
	return gf


func _draw() -> void:
	
	const LINE_COLOR := Color.WHITE
	const CONNECTION_LINE_COLOR := Color.LIGHT_GRAY
	const BASE_LINE_SIZE: float = 7.0
	
	#var circle_size: float = max(4, 8 * zoom)
	#var progress_shift: float = PROGRESS_SHIFT * zoom
	var line_width: float = BASE_LINE_SIZE * zoom
	
	for c: Dictionary in get_connection_list():
		var output_port_position: Vector2 = node_get_port_positon(get_node(String(c.from_node)), true)
		var input_port_position: Vector2 = node_get_port_positon(get_node(String(c.to_node)), false)
		var line := get_elbow_connection_line(output_port_position, input_port_position)
		draw_polyline(line, LINE_COLOR, line_width, true)
	
	if is_dragging_connection:
		var end_position: Vector2 = get_local_mouse_position()
		var port: Dictionary = get_closest_port_to_position(end_position)
		
		# Check if ports are of opposite type.
		if (port.left != !connecting_output) and \
				is_connection_valid(connecting_node if connecting_output else port.node, port.node if connecting_output else connecting_node) and \
				get_port_distance_squared(port.node, end_position) < get_port_range_squared(CONNECTING_SNAP_MOD_INCREASE):
			end_position = node_get_port_positon(port.node, not port.left)
		
		draw_polyline(get_elbow_connection_line(connection_start_position, end_position), CONNECTION_LINE_COLOR, line_width, true)
	
	if is_moving_node:
		update_dragged_nodes()

func is_connection_valid(from_node: RationalGraphNode, to_node: RationalGraphNode) -> bool:
	return from_node.component.can_parent(to_node.component)

func _is_node_hover_valid(from_node: StringName, from_port: int, to_node: StringName, to_port: int) -> bool:
	#node_get_comp(from_node).can_parent(node_get_comp(to_node))
	return node_get_comp(from_node).can_parent(node_get_comp(to_node))

func update_dragged_nodes() -> void:
	for node: RationalGraphNode in get_selected_nodes():
		var children: Array[RationalGraphNode] = node_get_children(node_get_parent(node.name))
		
		if children.size() < 2:
			continue
		
		for child: RationalGraphNode in children:
			child.is_drawing_index = true
			child.current_index = node_get_index(child)


func cancel_drag() -> void:
	if not is_moving_node: return
	reset_dragged_nodes = true
	var release_event:= InputEventMouseButton.new()
	release_event.button_index = MOUSE_BUTTON_LEFT
	get_viewport().push_input(release_event)

func _on_begin_node_move() -> void:
	is_moving_node = true

func _on_end_node_move() -> void:
	is_moving_node = false
	for node: RationalGraphNode in get_graph_nodes():
		node.is_drawing_index = false
	queue_redraw.call_deferred()
	reset_dragged_nodes = false

func _on_node_dragged(from: Vector2, to: Vector2, node: RationalGraphNode) -> void:
	#print("%s dragged %v => %v" % [node.component.resource_name, from, to])
	if from == to:
		return
	
	if reset_dragged_nodes:
		node.position_offset = from
		return
	
	update_component_index(node)
	action_handle.create_action("Moved Component(s)", UndoRedo.MERGE_ALL)
	
	undo_redo.add_do_method(self, &"move_component", node.component, to)
	undo_redo.add_undo_method(self, &"move_component", node.component, from)
	action_handle.commit(false)

#region UndoRedo

func create_action(action_name: String, merge_mode: UndoRedo.MergeMode = UndoRedo.MERGE_ALL) -> void:
	undo_redo.create_action(action_name, merge_mode, null, false, false)
	if active_root:
		if active_root.is_builtin() and not active_root.closed.is_connected(undo_redo.clear_history):
			active_root.closed.connect(undo_redo.clear_history.bind(EditorUndoRedoManager.GLOBAL_HISTORY))
		undo_redo.add_undo_method(active_root, &"edit")
		undo_redo.add_do_method(active_root, &"edit")

func commit(execute: bool = true) -> void:
	undo_redo.commit_action(execute)

#endregion UndoRedo

#region Selection

func clear_selected_node() -> void:
	selected_node = null

func select_components(components: Array[RationalComponent]) -> void:
	for node: RationalGraphNode in get_graph_nodes():
		node.selected = node.component in components

func select_comp(comp: RationalComponent) -> void:
	if comp_has_node(comp): return
	set_selected(comp_get_graph_node(comp))

func _on_node_selected(node: Node) -> void:
	selection.add_component(node.component)

func _on_node_deselected(node: Node) -> void:
	selection.remove_component(node.component)

func _on_selection_changed() -> void:
	select_components(selection.get_selected_components())

## Creates Action for UndoRedo.
func move_component(comp: RationalComponent, to_offset: Vector2) -> void:
	if not comp_has_node(comp): return
	comp_get_graph_node(comp).position_offset = to_offset

func comp_set_position_offset(comp: RationalComponent, position_offset: Vector2) -> void:
	if not comp_has_node(comp): return
	comp_get_graph_node(comp).position_offset = position_offset

func _on_component_children_changed(node: RationalGraphNode) -> void:
	update_node_connections(node)

func has_selected_node() -> bool:
	return not selection.get_selected_components().is_empty()

func get_selected_nodes() -> Array[RationalGraphNode]:
	var result: Array[RationalGraphNode]
	for comp: RationalComponent in get_selected_components():
		if not comp_has_node(comp): continue
		result.push_back(comp_get_graph_node(comp))
	return result

## If multiple nodes are selected, the one selected by the menu is chosen.
## If no node was selected by the menu, then it gets the closest to mouse.
func get_selected() -> RationalGraphNode:
	if selected_node:
		return selected_node
	
	#if get_node_at_position()
	
	var selected_nodes: Array[RationalGraphNode] = get_selected_nodes()
	if selected_nodes.is_empty(): 
		return null
	
	if selected_nodes.size() > 1:
		selected_nodes.sort_custom(sort_center_distance.bind(get_local_mouse_position()))
	
	return selected_nodes[0]

## Returns component of node returned from [method get_selected] if it exists. 
func get_selected_comp() -> RationalComponent:
	var node:= get_selected()
	return node.component if node else null

func get_selected_components() -> Array[RationalComponent]:
	return selection.get_selected_components()

#endregion Selection

func sort_center_distance(a: Control, b: Control, point: Vector2) -> bool:
	return a.get_rect().get_center().distance_squared_to(point) < b.get_rect().get_center().distance_squared_to(point)

func nodes_get_rect(nodes: Array[RationalGraphNode]) -> Rect2:
	if nodes.is_empty(): 
		return Rect2()
	
	var rect: Rect2 = Rect2(nodes.front().position_offset, nodes.front().size)
	for nod: GraphNode in nodes:
		rect = rect.merge(Rect2(nod.position_offset, nod.size))
	return rect

func get_graph_rect() -> Rect2:
	return nodes_get_rect(get_graph_nodes())

func node_get_port_positon(node: RationalGraphNode, output: bool) -> Vector2:
	if not node: return Vector2.ZERO
	return node.position + (node.get_output_position() if output else node.get_input_position()) * zoom


func is_input_closer(node: RationalGraphNode, point: Vector2) -> bool:
	return 	node_get_port_positon(node, false).distance_squared_to(point) <= \
			node_get_port_positon(node, true).distance_squared_to(point)

func get_port_distance_squared(node: RationalGraphNode, point: Vector2) -> float:
	return minf(node_get_port_positon(node, false).distance_squared_to(point),
				node_get_port_positon(node, true).distance_squared_to(point))

func sort_port_distance(a: RationalGraphNode, b: RationalGraphNode, point: Vector2) -> bool:
	return 	get_port_distance_squared(a, point) < get_port_distance_squared(b, point)

func get_closest_port_to_position(to_position: Vector2) -> Dictionary:
	var nodes:= get_graph_nodes()
	nodes.sort_custom(sort_port_distance.bind(to_position))
	return {node = nodes[0], left = is_input_closer(nodes[0], to_position)}

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
			action_handle.reparent_item(node.component, null, node_get_comp(con.from_node), UndoRedo.MERGE_ALL)
		
		if node.is_right_port_hovered and con.from_node == node.name:
			action_handle.reparent_item(node_get_comp(con.to_node), null, node.component, UndoRedo.MERGE_ALL)
	
	return true

func local_to_offset(local: Vector2) -> Vector2:
	return (local + scroll_offset)  / zoom

func _on_node_position_offset_changed(node: RationalGraphNode) -> void:
	queue_redraw.call_deferred()

func get_root_component() -> RationalComponent:
	return active_root.root if active_root else null

func toggle_layout() -> void:
	horizontal_layout = !horizontal_layout

func update_layout_button() -> void:
	layout_button.icon = EditorInterface.get_editor_theme().get_icon(&"MoveRight" if horizontal_layout else &"MoveDown", &"EditorIcons")
	layout_button.tooltip_text = "Switch to Vertical layout" if horizontal_layout else "Switch to Horizontal layout"

func _get_connection_line(from_position: Vector2, to_position: Vector2) -> PackedVector2Array:
	const VECS: PackedVector2Array = [Vector2(-9999999, -9999999), Vector2(-9999999, -9999999)]
	return VECS
