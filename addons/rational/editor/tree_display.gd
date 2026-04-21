@tool
extends Tree

const Util := preload("res://addons/rational/util.gd")
const Cache:= preload("../data/cache.gd")

const Selection:= preload("selection.gd")

const Menu := preload("popup_menu.gd")
const ActionHandle := preload("action_handle.gd")

const META_VISIBLE: StringName = &"Visible"

const COLOR_HIDDEN: Color = Color.DIM_GRAY
const COLOR_VISIBLE: Color = Color.WHITE

signal menu_item_selected(menu_item: int)
signal request_reparent()

##
signal selected_items_changed(items: Array[RationalComponent])

@export var tree_filter_line_edit: LineEdit

var menu: Menu

var active_root: RootData: set = set_active_root

var cache: Cache

var selection: Selection
var action_handle: ActionHandle
var deselect_queued: bool = false

func _ready() -> void:
	selection = Util.get_selection()
	selection.selection_changed.connect(_on_selection_changed)
	
	action_handle = Util.get_action_handle()
	
	item_mouse_selected.connect(_on_item_mouse_selected)
	multi_selected.connect(_on_multi_selected)
	button_clicked.connect(_on_button_clicked)
	
	
	menu = Menu.new()
	add_child(menu)
	menu.id_pressed.connect(_on_menu_id_pressed)
	
	tree_filter_line_edit.text_changed.connect(_on_filter_text_changed)

func show_popup(at_position: Vector2) -> void:
	menu.popup_at(get_menu_options(), get_screen_position() + at_position)

func _on_menu_id_pressed(id: int) -> void:
	match id:
		Menu.ITEM_RENAME:
			rename()
		_:
			menu_item_selected.emit(id, item_get_comp(get_item_at_position(Vector2(menu.position) - get_screen_position())))


func get_menu_options() -> int:
	var comps:= get_selected_components()
	
	var options: int = Menu.ITEMS_DEFAULT | Menu.ITEM_SHOW_IN_EDITOR | \
			((Menu.ITEM_PASTE_AS_SIBLING | Menu.ITEM_PASTE) * int(action_handle.has_clipboard()))
	
	if active_root.root in comps:
		options &= ~(Menu.ITEM_REPARENT | Menu.ITEM_PASTE_AS_SIBLING | Menu.ITEM_CUT)
	
	if comps.size() == 1:
		options |= Menu.ITEM_MOVE_DOWN | Menu.ITEM_MOVE_UP | Menu.ITEM_SAVE_AS_ROOT
		
		if comps[0] is Composite:
			options |=  Menu.ITEM_ADD_CHILD | Menu.ITEM_INSTANTIATE_NODE
		
		else:
			options &= ~Menu.ITEM_PASTE
	
	else:
		options &= ~(Menu.ITEM_CHANGE_TYPE | Menu.ITEM_PASTE | Menu.ITEM_PASTE_AS_SIBLING)
	
	return options

func rename() -> void:
	if not get_selected(): return
	edit_selected(true)

func edit_tree(data: RootData) -> void:
	set_active_root(data)

func set_active_root(data: RootData) -> void:
	if active_root == data: return
	
	if active_root:
		active_root.tree_changed.disconnect(_on_root_tree_changed)
	
	active_root = data
	
	populate_tree()
	
	if active_root:
		active_root.tree_changed.connect(_on_root_tree_changed)
	
	_on_selection_changed()

func _on_root_tree_changed() -> void:
	populate_tree()

func populate_tree() -> void:
	clear()
	if not active_root: 
		return
	
	if not active_root.is_loaded():
		active_root.loaded.connect(populate_tree, CONNECT_ONE_SHOT)
		return
	
	add_component(active_root.root)
	filter_items(tree_filter_line_edit.text if tree_filter_line_edit else "")
	set_selected_components.call_deferred(selection.get_selected_components())


func add_component(comp: RationalComponent, parent: TreeItem = null, recursive: bool = true) -> void:
	if not comp: return
	var item: TreeItem = create_item(parent)
	item.set_metadata(0, comp)
	item.set_icon(0, Util.comp_get_icon(comp))
	item.add_button(0, get_visible_icon(true), -1, false, "Toggle Visibility")
	item.set_meta(META_VISIBLE, true)
	item.set_text(0, comp.get_name())
	item.set_tooltip_text(0, "%s\nType: %s" % [comp.resource_name, Util.comp_get_class(comp)])
	
	const SIGNAL_NAME: String = "changed"
	item.add_user_signal(SIGNAL_NAME)
	comp.changed.connect(item.emit_signal.bind(SIGNAL_NAME))
	comp.script_changed.connect(item.emit_signal.bind(SIGNAL_NAME))
	item.connect(SIGNAL_NAME, _on_item_changed, CONNECT_APPEND_SOURCE_OBJECT)
	
	if not recursive:
		return
	
	for child: RationalComponent in comp.get_children():
		if not child: continue
		add_component(child, item)

func item_apply_filter(item: TreeItem, filter_text: String) -> bool:
	var any_child_visible: bool = false
	for child: TreeItem in item.get_children():
		any_child_visible = item_apply_filter(child, filter_text) or any_child_visible
	item.visible = any_child_visible or item_get_name(item).containsn(filter_text)
	if item.visible:
		item.uncollapse_tree()
	return item.visible

func filter_items(text: String) -> void:
	
	if not text:
		get_root().call_recursive("set_visible", true)
		return
	
	item_apply_filter(get_root(), text)


func item_get_name(item: TreeItem) -> String:
	return item.get_text(0)

func item_get_comp(item: TreeItem) -> RationalComponent:
	return item.get_metadata(0) if item else null


func item_get_subtree(item: TreeItem) -> Array[TreeItem]:
	if not item: return []
	var result: Array[TreeItem] = [item]
	for child: TreeItem in item.get_children():
		result.append_array(item_get_subtree(child))
	return result


func get_all_items() -> Array[TreeItem]:
	return item_get_subtree(get_root())


func item_is_visible(item: TreeItem) -> bool:
	return item.get_meta(META_VISIBLE, false)


func item_set_visible(item: TreeItem, item_visible: bool) -> void:
	item.set_meta(META_VISIBLE, item_visible)
	item.set_button(0, 0, get_visible_icon(item_visible))
	item_set_visible_modulate(item)


func item_set_visible_modulate(item: TreeItem) -> void:
	var visible_in_tree: bool = item_visible_in_tree(item)
	var button_color: Color = COLOR_VISIBLE if visible_in_tree else COLOR_HIDDEN
	if button_color == item.get_button_color(0, 0): return
	item.set_button_color(0, 0, button_color)
	for child: TreeItem in item.get_children():
		item_set_visible_modulate(child)

func item_visible_in_tree(item: TreeItem) -> bool:
	while item:
		if not item_is_visible(item):
			return false
		item = item.get_parent()
	return true

func _on_filter_text_changed(new_text: String) -> void:
	filter_items(new_text)

func _on_item_changed(item: TreeItem) -> void:
	if item.get_text(0) != item.get_metadata(0).resource_name:
		item.set_text(0, generate_unique_name(item))


func _on_button_clicked(item: TreeItem, column: int, id: int, mouse_button_index: int) -> void:
	item_set_visible(item, item.get_button(column,id) == get_theme_icon(&"GuiVisibilityHidden", &"EditorIcons"))

func get_visible_icon(item_visible: bool) -> Texture2D:
	return get_theme_icon(&"GuiVisibilityVisible", &"EditorIcons") if item_visible else get_theme_icon(&"GuiVisibilityHidden", &"EditorIcons")

func set_cache(val: Cache) -> void:
	cache = val
	cache.edited_tree_changed.connect(edit_tree)

func get_all_selected_items() -> Array[TreeItem]:
	var selected_items: Array[TreeItem]
	var item: TreeItem = get_root() if get_root().is_selected(0) else get_next_selected(get_root())
	while item:
		selected_items.push_back(item)
		item = get_next_selected(item)
	return selected_items

func get_selected_components() -> Array[RationalComponent]:
	return selection.get_selected_components()

func set_selected_components(components: Array[RationalComponent]) -> void:
	for item: TreeItem in get_all_items():
		item_set_selected(item, item_get_comp(item) in components)


## Sets item selected = [param selected] and uncollapses tree if selected. 
func item_set_selected(item: TreeItem, selected: bool) -> void:
	if not selected:
		item.deselect(0)
		return
	
	item.select(0)
	item.uncollapse_tree()


## Sets [param item.root.resource_name] if different.
func generate_unique_name(item: TreeItem) -> String:
	if not item or not item_get_comp(item): return ""
	var comp: RationalComponent = item_get_comp(item)
	
	if not comp.resource_name:
		comp.resource_name = Util.comp_get_class(comp)
	
	var name_list: PackedStringArray
	if item.get_parent():
		for sibling: TreeItem in item.get_parent().get_children():
			if item == sibling: continue
			name_list.push_back(sibling.get_text(0))
	
	return Util.generate_unique_name(comp.resource_name, name_list)

func filter_children(items: Array[TreeItem]) -> Array[TreeItem]:
	var result: Array[TreeItem] = items.duplicate()
	var i: int = result.size()
	while i > 0:
		i -= 1
		if result[i].get_parent() in items:
			result.remove_at(i)
	return result

#region Drag&Drop

func move_items(to_position: Vector2, items: Array[TreeItem]) -> void:
	var item: TreeItem = get_item_at_position(to_position)
	if not item:
		return
	
	var index: int = get_drop_section_at_position(to_position)
	if index != 0:
		index = item.get_index() + maxi(0, index)
		item = item.get_parent()
	else:
		index = -1
	
	var target_parent: RationalComponent = item_get_comp(item)
	if not target_parent or not target_parent is Composite:
		return
	
	var top_components: Array[RationalComponent] = selection.get_top_selected_components()
	
	if target_parent in top_components:
		return
	#var roots: Array[TreeItem] = filter_children(items)
	
	if 1 < top_components.size() and target_parent is Decorator:
		return
	
	for comp: RationalComponent in top_components:
		request_reparent.emit(comp, active_root.root.find_parent(comp), target_parent, index)


func _can_drop_data(at_position: Vector2, data: Variant) -> bool:
	if data is Dictionary:
		match data.get("type", ""):
			"items" when data.get("source") == self:
				drop_mode_flags = DROP_MODE_INBETWEEN | DROP_MODE_ON_ITEM
				return true
	return false

func _drop_data(at_position: Vector2, data: Variant) -> void:
	if data is Dictionary:
		match data.get("type", ""):
			"items":
				move_items(at_position, data.get("items", []))

# { "type": "files", "files": ["res://BitMap.tres"], "from": @Tree@5673:<Tree#495833867875> }
func _get_drag_data(at_position: Vector2) -> Variant:
	var selected_items: Array[TreeItem] = get_all_selected_items()
	
	if selected_items.is_empty():
		return null
	
	var vbox: VBoxContainer = VBoxContainer.new()
	for i: TreeItem in selected_items:
		var button: Button = Button.new()
		button.flat = true
		button.text = i.get_text(0)
		button.icon = i.get_icon(0)
		button.modulate.a = 0.65
		vbox.add_child(button)
	set_drag_preview(vbox)
	return {type = "items", items = selected_items, source = self}

#endregion 


func _on_item_mouse_selected(mouse_position: Vector2, mouse_button_index: int) -> void:
	if mouse_button_index == MOUSE_BUTTON_RIGHT:
		show_popup(mouse_position)

	

func _on_selection_changed() -> void:
	set_selected_components(selection.get_selected_components())

func _on_multi_selected(item: TreeItem, column: int, selected: bool) -> void:
	if not deselect_queued:
		deselect_queued = true
		update_selection.call_deferred()
	
	if selected:
		selection.add_component(item_get_comp(item))
		return
	
	selection.remove_component(item_get_comp(item))

func update_selection() -> void:
	if not deselect_queued: return
	var selected_item_components: Array[RationalComponent]
	selected_item_components.assign(get_all_selected_items().map(item_get_comp))
	for comp: RationalComponent in selection.get_selected_components():
		if comp in selected_item_components: continue
		selection.remove_component(comp)
	#selection.set_selected(selected_item_components)
	deselect_queued = false
