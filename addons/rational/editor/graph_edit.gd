@tool
extends GraphEdit

#const META_POPUP: StringName = &"block_call"
#signal preview_created(root: RootData, preview: Image)

const Util := preload("../util.gd")

const EditorStyle = preload("editor_style.gd")
const RationalGraphNode := preload("graph_node.gd")
const CreatePopup = preload("component_dialog.gd") 
const Menu := preload("popup_menu.gd")
const ActionHandle := preload("action_handle.gd")


const PROGRESS_SHIFT: int = 50
const PORT_RANGE: float = 20
const CONNECTING_SNAP_MOD_INCREASE: float = 2.5

signal selected_changed(nodes: Array[RationalComponent])
signal clipboard_changed

@export var popup: CreatePopup
@export var tree_display: Tree

var style: EditorStyle
var layout_button: Button

var menu: Menu

var updating_graph: bool = false
var arranging_nodes: bool = false
var restoring_state: bool = false

var graph_update_queued: bool = false

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

var block_selection_signal: bool = false

var is_restoring_state: bool = false

var reset_dragged_nodes: bool = false

#var undo_redo: UndoRedo = UndoRedo.new() # TODO - may use editor undoredo

var shortcuts: Dictionary[Shortcut, Callable]

var action_handle: ActionHandle

var undo_redo: EditorUndoRedoManager

## Node selected with right click when creating a menu.
var selected_node: RationalGraphNode


func _ready() -> void:
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
	
	node_selected.connect(_on_node_selection_changed)
	node_deselected.connect(_on_node_selection_changed)
	
	begin_node_move.connect(_on_begin_node_move)
	end_node_move.connect(_on_end_node_move)
	
	popup_request.connect(_on_popup_request)
	
	action_handle = Util.get_action_handle()
	undo_redo = Util.get_undo_redo()
	
	menu = Menu.new()
	add_child(menu)
	menu.id_pressed.connect(_on_menu_id_pressed)
	
	init_shortcuts()

#region Menu

func _on_popup_request(at_position: Vector2) -> void:
	if is_moving_node:
		cancel_drag()
		return
	
	if disconnect_hovered_port():
		print("Hovered port disconnected.")
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

## Checks
func get_menu_options(node: RationalGraphNode = null) -> int:
	if not node:
		return Menu.ITEMS_HERE ^ (Menu.ITEM_PASTE_HERE * int(not action_handle.has_clipboard()))
	
	var selected_nodes:= get_selected_nodes()
	
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
			pass
		Menu.ITEM_MOVE_NODE_HERE:
			pass
		Menu.ITEM_PASTE_AS_SIBLING:
			pass


#endregion Menu

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


#region shortcuts

func select_and_center(comp: RationalComponent) -> void:
	if not comp or not comp_has_node(comp): return
	set_selected(comp_get_graph_node(comp))
	center_selection()


func instantiate_child() -> void:
	var node:= get_selected()
	if not node or not node.component is Composite: return
	action_handle.prompt_instantiate_child(node.component)


func add_child_component() -> void:
	action_handle.prompt_add_child(get_selected_comp())

func cut() -> void:
	if is_dragging_connection: return
	var comps: Array[RationalComponent] = get_selected_components()
	if not comps: return
	action_handle.copy(comps)
	#undo_redo.create_action("")
	#for comp: RationalComponent in get_selected_components():
		#clipboard.push_back(comp)
		#delete_node(comp_get_node_name(comp))
	#printt("CUT: ", clipboard)

func copy() -> void:
	if is_dragging_connection: return
	action_handle.copy(get_selected_components())

func paste() -> void:
	if is_dragging_connection or not action_handle.can_paste(): 
		return
	
	if has_selected_node():
		action_handle.paste(get_selected(false).component)
		return
	
	paste_here()

func paste_here() -> void:
	#print("Pasting here...")
	action_handle.create_action("Paste Component(s)", UndoRedo.MERGE_DISABLE)
	var orphan_offset: Vector2 = nodes_get_rect(get_graph_nodes()).end * get_layout_dir()
	var components: Array[RationalComponent] = action_handle.get_clipboard(true)
	
	for comp: RationalComponent in components:
		var n: RationalGraphNode = add_node(comp)
		undo_redo.add_undo_method(self, &"remove_child", n)
		undo_redo.add_do_method(self, &"add_child", n)
		undo_redo.add_do_reference(n)
	
	place_orphans(components, orphan_offset)
	action_handle.commit(false)

#func add_orphan()


func duplicate_components() -> void:
	if is_dragging_connection or not has_selected_node():
		return
	
	var comps: Array[RationalComponent]
	for node in get_selected_nodes():
		comps.push_back(node.component)
	printt("DUPLICATE: ", comps)
	#filter_child_components(comps)
	for i: int in comps.size():
		comps[i] = comps[i].duplicate(true)
	
	place_orphans(comps, nodes_get_rect(get_graph_nodes()).end * get_layout_dir())


func delete() -> void:
	if is_dragging_connection: return
	if has_selected_node():
		delete_node(get_selected().name)


## Only prompts to change type. Does not change any scripts.
func change_type() -> void:
	if not is_dragging_connection and has_selected_node(): 
		get_selected().prompt_change_type()

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


func node_arrange_children(node: RationalGraphNode) -> void:
	if not node: return
	
	#var children: Dictionary[RationalComponent, RationalGraphNode] 
	
	#for child: RationalComponent in node.component.get_children():
		#children[child] = comp_get_graph_node(child)

func show_quick_create_popup(at_position: Vector2) -> void:
	if active_root:
		popup.open(at_position, create_component.bind(at_position - global_position))

func create_child_component(script_path: String, parent: Composite) -> void:
	if not Util.script_path_is_valid(script_path): return
	var child: RationalComponent = ResourceLoader.load(script_path, "GDScript").new()
	print_rich("[color=green]Child Created: %s | Parent: %s[/color]" % [child, parent])
	parent.add_child(child)

func create_component(_class: StringName, at_position: Vector2 = Vector2.ZERO) -> void:
	if not _class or not Util.class_is_valid(_class): return
	var comp: RationalComponent = Util.instantiate_class(_class)
	var node: RationalGraphNode = add_node(comp)
	place_node_at(node, ((at_position if at_position else size/2.0 - node.size/2.0) + scroll_offset)  / zoom)
	
	action_handle.create_action("Create Component")
	undo_redo.add_undo_method(self, &"remove_child", node)
	undo_redo.add_do_method(self, &"add_child", node)
	undo_redo.add_do_reference(node)
	action_handle.commit(false)
	
	print_rich("[color=green]Node Created: %s[/color]" % comp)


func place_node_at(node: RationalGraphNode, offset: Vector2) -> void:
	# TODO: Add check for collision and adjust
	node.position_offset = offset

func _on_connection_drag_started(from_node: StringName, from_port: int, is_output: bool) -> void:
	print("Connection drag started")
	connecting_node = get_node(String(from_node))
	connecting_output = is_output
	connection_start_position = get_node_port_position(connecting_node, is_output) * zoom
	is_dragging_connection = true
	accept_event()
	queue_redraw()

func _on_connection_drag_ended() -> void:
	print("Connection drag ended")
	connecting_node = null
	is_dragging_connection = false
	queue_redraw()

func _on_connection_request(from_node: StringName, from_port: int, to_node: StringName, to_port: int) -> void:
	if not from_port == to_port and from_port == 0:
		printerr("Attempting to connect graph node port != 0.")
		return
	
	var current_parent:= node_get_parent(to_node)
	var current_parent_comp:= current_parent.component if current_parent else null
	action_handle.reparent_item(node_get_comp(to_node), node_get_comp(from_node), current_parent_comp)


func _on_delete_nodes_request(nodes: Array[StringName]) -> void:
	if is_dragging_connection: return
	for node_name: StringName in nodes:
		delete_node(node_name)


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

	#for graph_node: RationalGraphNode in get_graph_nodes():
		#graph_node.selected = graph_node == node

## Recursively adds all children.
func add_node(comp: RationalComponent) -> RationalGraphNode:
	if not comp: return
	
	if comp_has_node(comp):
		pass
	
	var node: RationalGraphNode = RationalGraphNode.new(style, horizontal_layout)
	add_child(node)
	
	node.set_component(comp)
	node.component_children_changed.connect(_on_component_children_changed, CONNECT_APPEND_SOURCE_OBJECT | CONNECT_DEFERRED)
	node.dragged.connect(_on_node_dragged, CONNECT_APPEND_SOURCE_OBJECT)
	node.position_offset_changed.connect(_on_node_position_offset_changed, CONNECT_APPEND_SOURCE_OBJECT | CONNECT_DEFERRED)
	node.resized.connect(queue_redraw, CONNECT_DEFERRED)
	node.slot_sizes_changed
	
	node.set_slots(comp != get_root_component(), comp is Composite)
	
	for child: RationalComponent in comp.get_children():
		var child_node:= add_node(child)
		connect_node(node.name, 0, child_node.name, 0)
	
	return node


func delete_node(node_name: StringName) -> void:
	var node: RationalGraphNode = get_node(String(node_name))
	
	if not node or node.component == get_root_component():
		return
	
	if get_root_component() == node.component:
		push_warning("Cannot delete root node.")
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


func node_get_children(node: RationalGraphNode) -> Array[RationalGraphNode]:
	if not node: return []
	var result: Array[RationalGraphNode]
	for con: Dictionary in get_connection_list_from_node(node.name):
		if con.from_node == node.name:
			result.push_back(get_node(String(con.to_node)))
	return result


## Only updates child connections.
func update_node_connections(node: RationalGraphNode) -> void:
	for child_node: RationalGraphNode in node_get_children(node):
		if child_node and node.component.has_child(child_node.component): continue
		disconnect_node(node.name, 0, child_node.name, 0)
	
	for child: RationalComponent in node.component.get_children():
		if not comp_has_node(child):
			var child_node:= add_node(child)
			parent_place_child(child_node, node)
			
		if not is_node_connected(node.name, 0, comp_get_node_name(child), 0):
			connect_node(node.name, 0, comp_get_node_name(child), 0)

func parent_place_child(child: RationalGraphNode, parent: RationalGraphNode) -> void:
	assert(child.component in parent.component.get_children())
	var sibling_axis: int = int(horizontal_layout)
	var level_axis: int = abs(sibling_axis - 1)
	print("sibling_axis: %s | level_axis: %s" %[sibling_axis, level_axis])
	
	child.position_offset[level_axis] = parent.position_offset[level_axis] + parent.size[level_axis] + TreeNode.LEVEL_DISTANCE

	
	if parent.component.get_child_count() <= 1:
		child.position_offset[sibling_axis] = parent.position_offset[sibling_axis] + (parent.size - child.size)[sibling_axis]/2.0
		print("Parent: %s | Child: %s" % [parent.get_rect(), child.get_rect()])
		return
	
	var idx: int = parent.component.get_child_index(child.component)
	assert(-1 < idx and idx < parent.component.get_child_count(), "OOB child index from 'get_child_index' function." )
	var children: Array[RationalGraphNode] = node_get_children_sorted(parent)
	children.erase(child)
	if idx == 0:
		child.position_offset[sibling_axis] = children[0].position_offset[sibling_axis] - TreeNode.SIBLING_DISTANCE
	elif idx >= parent.component.get_child_count() - 1:
		child.position_offset[sibling_axis] = children[-1].position_offset[sibling_axis] + children[-1].size[sibling_axis] + TreeNode.SIBLING_DISTANCE
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
	tree_node.update_positions(horizontal_layout)
	place_nodes(tree_node)
	
	var offset: Vector2 = get_tree_end(tree_node) * Vector2(float(horizontal_layout), float(!horizontal_layout))
	place_orphans(get_active_root_orphans(), offset)
	
	arranging_nodes = false


#func arrange_subtree(subtree_root: RationalGraphNode) -> void:
	#if arranging_nodes or not subtree_root: return
	#arranging_nodes = true
	#var tree_node:= create_tree_node(subtree_root.component)
	#arranging_nodes = false


func place_nodes(node: TreeNode) -> void:
	node.item.position_offset = Vector2(node.x, node.y)
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
		offset_component(comp, offset)


func offset_component(comp: RationalComponent, offset: Vector2) -> void:
	comp_get_graph_node(comp).position_offset += offset
	for child in comp.get_children():
		offset_component(child, offset)

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

func get_graph_nodes() -> Array[RationalGraphNode]:
	var result: Array[RationalGraphNode]
	for child in get_children():
		if child is RationalGraphNode:
			result.push_back(child)
	return result


func get_orphan_nodes() -> Array[RationalGraphNode]:
	var result: Array[RationalGraphNode]
	for node: RationalGraphNode in get_graph_nodes():
		if node.component == get_root_component() or node_is_parented(node.name): continue
		result.push_back(node)
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
			var node: RationalGraphNode = get_selected(false)
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
				print(action_handle.get_clipboard(false, Resource.DEEP_DUPLICATE_NONE))
			
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


func _on_node_selection_changed(node: Node) -> void:
	if block_selection_signal: return
	selected_changed.emit(get_selected_components())


func _on_node_dragged(from: Vector2, to: Vector2, node: RationalGraphNode) -> void:
	#print("%s dragged %v => %v" % [node.component.resource_name, from, to])
	
	if reset_dragged_nodes:
		node.position_offset = from
		return
	
	action_handle.create_action("Moved Component(s)", UndoRedo.MERGE_ALL)
	undo_redo.add_undo_property(node, &"position_offset", from)
	undo_redo.add_do_property(node, &"position_offset", to)
	action_handle.commit(false)
	
	update_component_index(node)


func _on_component_children_changed(node: RationalGraphNode) -> void:
	update_node_connections(node)

func _get_connection_line(from_position: Vector2, to_position: Vector2) -> PackedVector2Array:
	const VECS: PackedVector2Array = [Vector2(-9999999, -9999999), Vector2(-9999999, -9999999)]
	return VECS

func has_selected_node() -> bool:
	for node: RationalGraphNode in get_graph_nodes():
		if node.selected: 
			return true
	return false

func get_selected_nodes() -> Array[RationalGraphNode]:
	var result: Array[RationalGraphNode]
	for node: RationalGraphNode in get_graph_nodes():
		if not node.selected: continue
		result.push_back(node)
	return result

## If multiple nodes are selected, the one at the menu's position is chosen.
## If no node at the menu position is found, it then chooses
func get_selected(prioritize_menu: bool = true) -> RationalGraphNode:
	if prioritize_menu:
		var menu_node: RationalGraphNode = get_node_at_position(Vector2(menu.position) - global_position)
		if menu_node and menu_node.selected:
			return menu_node
	
	var selected_nodes: Array[RationalGraphNode] = get_selected_nodes()
	if selected_nodes.is_empty(): 
		return null
	
	if selected_nodes.size() > 1:
		
		
		selected_nodes.sort_custom(sort_center_distance.bind(get_local_mouse_position()))
	
	return selected_nodes[0]

## Returns component of node returned from [method get_selected] if it exists. 
func get_selected_comp(prioritize_menu: bool = true) -> RationalComponent:
	var node:= get_selected(prioritize_menu)
	return node.component if node else null

func sort_center_distance(a: Control, b: Control, point: Vector2) -> bool:
	return a.get_rect().get_center().distance_squared_to(point) < b.get_rect().get_center().distance_squared_to(point)


func get_selected_components() -> Array[RationalComponent]:
	var result: Array[RationalComponent]
	for node: RationalGraphNode in get_selected_nodes():
		result.push_back(node.component)
	return result

func nodes_get_rect(nodes: Array[RationalGraphNode]) -> Rect2:
	if nodes.is_empty(): 
		return Rect2()
	
	var rect: Rect2 = Rect2(nodes.front().position_offset, nodes.front().size)
	for nod: GraphNode in nodes:
		rect = rect.merge(Rect2(nod.position_offset, nod.size))
	return rect

func get_graph_rect() -> Rect2:
	return nodes_get_rect(get_graph_nodes())

func _on_tree_display_selected_items_changed(items: Array[RationalComponent]) -> void:
	block_selection_signal = true
	for node: RationalGraphNode in get_graph_nodes():
		node.selected = node.component in items
	block_selection_signal = false

func node_get_port_positon(node: RationalGraphNode, output: bool) -> Vector2:
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
#
#func is_menu_in_screen_rect() -> bool:
	#return Rect2(get_screen_position(), size).has_point(menu.position)

#func _on_menu_pressed(index: int) -> void:
	##print("RightClick Menu Item pressed: %s" % menu.get_item_text(index))
	#match menu.get_item_text(index):
		#"Rename" when not is_menu_in_screen_rect():
			#tree_display.edit_selected(true)
		#
	#menu.get_item_metadata(index).call()
func local_to_offset(local: Vector2) -> Vector2:
	return (local + scroll_offset)  / zoom


func _on_node_position_offset_changed(node: RationalGraphNode) -> void:
	queue_redraw()

func get_root_component() -> RationalComponent:
	return active_root.root if active_root else null

func toggle_layout() -> void:
	horizontal_layout = !horizontal_layout

func update_layout_button() -> void:
	layout_button.icon = EditorInterface.get_editor_theme().get_icon(&"MoveRight" if horizontal_layout else &"MoveDown", &"EditorIcons")
	layout_button.tooltip_text = "Switch to Vertical layout" if horizontal_layout else "Switch to Horizontal layout"
