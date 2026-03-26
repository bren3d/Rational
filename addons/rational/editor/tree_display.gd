@tool
extends Tree

const Util := preload("res://addons/rational/util.gd")
const Cache:= preload("../data/cache.gd")

const META_VISIBLE: StringName = &"Visible"

const COLOR_HIDDEN: Color = Color.DIM_GRAY
const COLOR_VISIBLE: Color = Color.WHITE

@export var tree_filter_line_edit: LineEdit

signal selected_items_changed(items: Array[RationalComponent])

var active_root: RootData: set = set_active_root

var cache: Cache
var block_selection_signal: bool = false


func _ready() -> void:
	if not cache: return
	tree_filter_line_edit.text_changed.connect(_on_filter_text_changed)
	cache.edited_tree_changed.connect(edit_tree)


func apply_theme() -> void:
	pass

func edit_tree(data: RootData) -> void:
	set_active_root(data)

func set_active_root(data: RootData) -> void:
	if active_root == data: return
	
	if active_root:
		active_root.tree_changed.disconnect(_on_root_tree_changed)
	
	active_root = data
	
	#tree_filter_line_edit.clear()
	if active_root:
		populate_tree()
		active_root.tree_changed.connect(_on_root_tree_changed)

func _on_root_tree_changed() -> void:
	reload_tree()

func reload_tree() -> void:
	if not active_root: return
	var selected: Array[RationalComponent] = get_selected_components()
	populate_tree()
	set_selected_components.call_deferred(selected)

func populate_tree() -> void:
	clear()
	add_component(active_root.root)
	filter_items(tree_filter_line_edit.text if tree_filter_line_edit else "")


func add_component(comp: RationalComponent, parent: TreeItem = null, recursive: bool = true) -> void:
	var item: TreeItem = create_item(parent)
	item.set_metadata(0, comp)
	item.set_icon(0, cache.comp_get_icon(comp))
	item.add_button(0, get_visible_icon(true), -1, false, "Toggle Visibility")
	item.set_meta(META_VISIBLE, true)
	item.set_text(0, generate_unique_name(item))
	item.set_tooltip_text(0, "%s\nType: %s" % [comp.resource_name, cache.comp_get_class(comp)])
	
	const SIGNAL_NAME: String = "changed"
	item.add_user_signal(SIGNAL_NAME)
	comp.changed.connect(item.emit_signal.bind(SIGNAL_NAME))
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
	return item.get_metadata(0)


func item_get_subtree(item: TreeItem) -> Array[TreeItem]:
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
	
	var parent_visible: bool = item_visible
	var parent: TreeItem = item.get_parent()
	while item_visible and parent:
		item_visible = item_is_visible(parent)
		parent = parent.get_parent()
	
	item_set_visible_modulate(item, parent_visible)


func item_set_visible_modulate(item: TreeItem, parent_visible: bool) -> void:
	var modulate_color: Color = COLOR_VISIBLE if parent_visible and item_is_visible(item) else COLOR_HIDDEN
	item.set_button_color(0, 0, modulate_color)
	for child: TreeItem in item.get_children():
		item_set_visible_modulate(child, parent_visible)
	

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

func get_all_selected() -> Array[TreeItem]:
	var selected_items: Array[TreeItem]
	var item: TreeItem = get_root() if get_root().is_selected(0) else get_next_selected(get_root())
	while item:
		selected_items.push_back(item)
		item = get_next_selected(item)
	return selected_items

func get_selected_components() -> Array[RationalComponent]:
	var selected_comps: Array[RationalComponent]
	for i: TreeItem in get_all_selected():
		selected_comps.push_back(item_get_comp(i))
	return selected_comps

func set_selected_components(components: Array[RationalComponent]) -> void:
	block_selection_signal = true
	for item: TreeItem in get_all_items():
		if item_get_comp(item) in components:
			item.select(0)
			item.uncollapse_tree()
		else:
			item.deselect(0)
	block_selection_signal = false


## Sets [param item.root.resource_name] if different.
func generate_unique_name(item: TreeItem) -> String:
	if not item or not item_get_comp(item): return ""
	var comp: RationalComponent = item_get_comp(item)
	
	if not comp.resource_name:
		comp.resource_name = cache.comp_get_class(comp)
	
	var name_list: PackedStringArray
	if item.get_parent():
		for sibling: TreeItem in item.get_parent().get_children():
			if item == sibling: continue
			name_list.push_back(sibling.get_text(0))
	
	return cache.generate_unique_name(comp.resource_name, name_list)


#region Drag&Drop

func move_items(to_position: Vector2, items: Array[TreeItem]) -> void:
	var i: int = items.size()
	while i > 0:
		i -= 1
		if items[i].get_parent() in items:
			items.remove_at(i)
	printt("Moving items: ", items)


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
				#move_item(at_position, data.item)

# { "type": "files", "files": ["res://BitMap.tres"], "from": @Tree@5673:<Tree#495833867875> }
func _get_drag_data(at_position: Vector2) -> Variant:
	var selected_items: Array[TreeItem] = get_all_selected()
	
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


func _on_multi_selected(item: TreeItem, column: int, selected: bool) -> void:
	if block_selection_signal: return
	selected_items_changed.emit(get_selected_components())


func _on_graph_edit_selected_changed(components: Array[RationalComponent]) -> void:
	set_selected_components(components)
