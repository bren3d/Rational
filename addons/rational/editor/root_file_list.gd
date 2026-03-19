@tool
extends Tree

const Util := preload("res://addons/rational/util.gd")
const Cache:= preload("../data/cache.gd")

const META_PATH: StringName = &"path"

enum {COMMAND_SAVE, COMMAND_SAVE_AS, COMMAND_CLOSE, COMMAND_CLOSE_OTHERS, COMMAND_CLOSE_BELOW, COMMAND_CLOSE_ALL, COMMAND_MAX}

signal root_edit_request(root: RationalComponent)

@export var filter_line_edit: LineEdit

@export var add_root_button: Button

@export var popup: PopupMenu

var cache: Cache

var shortcuts: Array[Shortcut]



func _ready() -> void:
	if not cache: return
	
	shortcuts.resize(COMMAND_MAX)
	var editor_settings: EditorSettings = EditorInterface.get_editor_settings()
	shortcuts[COMMAND_SAVE] = editor_settings.get_shortcut("scene_tree/save")
	shortcuts[COMMAND_SAVE_AS] = editor_settings.get_shortcut("scene_tree/save_as")
	shortcuts[COMMAND_CLOSE] = editor_settings.get_shortcut("script_editor/close_file")
	shortcuts[COMMAND_CLOSE_OTHERS] = editor_settings.get_shortcut("script_editor/close_other_tabs")
	shortcuts[COMMAND_CLOSE_BELOW] = editor_settings.get_shortcut("script_editor/close_tabs_below")
	shortcuts[COMMAND_CLOSE_ALL] = editor_settings.get_shortcut("script_editor/close_all")
	
	init_popup()
	
	await cache.load()
	
	build_list()
	
	filter_line_edit.text_changed.connect(_on_filter_text_changed)
	add_root_button.pressed.connect(_on_add_root_button_pressed)
	
	item_selected.connect(_on_item_selected)
	
	cache.root_added.connect(add_data)
	cache.root_erased.connect(erase_data)


func build_list() -> void:
	clear()
	create_item()
	for data: RootData in cache.get_data_list():
		add_data(data)

func has_root(root: RationalComponent) -> bool:
	return root_get_item(root) != null

func has_path(path: String) -> bool:
	return path_get_item(path) != null

func item_get_data(item: TreeItem) -> RootData:
	return item.get_metadata(0)

func data_get_item(data: RootData) -> TreeItem:
	for item: TreeItem in get_root().get_children():
		if item_get_data(item) == data:
			return item
	return null

func has_data(data: RootData) -> bool:
	return data_get_item(data) != null


func item_get_path(item: TreeItem) -> String:
	return item_get_data(item).path if item else ""

func item_get_root(item: TreeItem) -> RationalComponent:
	return item_get_data(item).root if item else null

func path_get_item(path: String) -> TreeItem:
	for item: TreeItem in get_root().get_children():
		if item_get_path(item) == path:
			return item
	return null

func root_get_item(root: RationalComponent) -> TreeItem:
	for item: TreeItem in get_root().get_children():
		if item_get_root(item) == root:
			return item
	return null


func close_item(item: TreeItem) -> void:
	if not item: return
	
	var data: RootData = item_get_data(item)
	
	if data.unsaved_changes:
		# TODO
		return
	
	item_get_data(item).closed.emit()


func add_data(data: RootData) -> void:
	if has_data(data): return
	var item: TreeItem = create_item()
	item.set_metadata(0, data)
	update_item(item)
	data.changed.connect(_on_data_changed.bind(item))
	data.unsaved_changes_changed.connect(_on_data_changed.bind(item))
	data.request_edit.connect(select_data, CONNECT_APPEND_SOURCE_OBJECT)
	data.closed.connect(_on_data_closed.bind(item))

func add_root(root: RationalComponent, force_path: String = "") -> void:
	if not root: return
	cache.add_root(root, force_path)


func update_item(item: TreeItem) -> void:
	if not item: return
	var data: RootData = item_get_data(item)
	item.set_text(0, data_get_name(data))
	item.set_icon(0, data_get_icon(data))
	item.set_tooltip_text(0, data_get_tooltip(data))

func data_get_name(data: RootData) -> String:
	return data.name + (" (*)" if data.unsaved_changes else "") 

func data_get_icon(data: RootData) -> Texture2D:
	return cache.data_get_icon(data)

func data_get_tooltip(data: RootData) -> String:
	return "Type: %s\nPath: %s" % [data.class_of_root, data.path]

func erase_item(item: TreeItem) -> void:
	if not item: return
	var data: RootData = item_get_data(item)
	cache.erase_data(data)
	
	# TODO - UndoRedo

func erase_data(data: RootData) -> void:
	erase_item(data_get_item(data))

func erase_path(path: String) -> void:
	if not path: return
	erase_item(path_get_item(path))

func _on_data_closed(item: TreeItem) -> void:	
	if not item: return
	item.free()

func _on_data_changed(item: TreeItem) -> void:
	update_item(item)

func filter_list(filter: String = "") -> void:
	for item: TreeItem in get_root().get_children():
		item.visible = item.get_text(0).containsn(filter) if filter else true

func _on_filter_text_changed(new_text: String) -> void:
	filter_list(new_text)

func edit_data(data: RootData) -> void:
	if not data: return
	data.request_edit.emit()

func edit_tree(tree: RationalTree) -> void:
	if not tree: return
	if not tree.root:
		prompt_new_root(tree)
		return
	
	cache.add_root(tree.root)
	edit_data.call_deferred(cache.root_get_data(tree.root))

func select_data(data: RootData) -> void:
	if not data or get_selected() == data_get_item(data): return
	data_get_item(data).select(0)
	ensure_cursor_is_visible()

func _on_item_selected() -> void:
	var item: TreeItem = get_selected()
	if not item: return
	edit_data(item_get_data(item))

func _on_add_root_button_pressed() -> void:
	prompt_new_root()

func prompt_new_root(for_tree: RationalTree = null) -> void:
	# TODO
	pass

func set_cache(val: Cache) -> void:
	cache = val

#region RightClickMenu


func save_item(item: TreeItem) -> void:
	cache.save_data(item_get_data(item))

func save_item_as(item: TreeItem) -> void:
	cache.save_data_as(item_get_data(item))

func shortcut_get_accel(command_idx: int) -> Key:
	if shortcuts[command_idx]:
		for event in shortcuts[command_idx].events:
			if event is InputEventKey:
				return event.get_keycode_with_modifiers()
	return KEY_NONE


func init_popup() -> void:
	popup.clear()
	popup.add_item("Save", COMMAND_SAVE, shortcut_get_accel(COMMAND_SAVE))
	popup.add_item("Save As...", COMMAND_SAVE_AS, shortcut_get_accel(COMMAND_SAVE_AS))
	popup.add_item("Close", COMMAND_CLOSE, shortcut_get_accel(COMMAND_CLOSE))
	popup.add_item("Close Other Tabs", COMMAND_CLOSE_OTHERS, shortcut_get_accel(COMMAND_CLOSE_OTHERS))
	popup.add_item("Close Tabs Below", COMMAND_CLOSE_BELOW, shortcut_get_accel(COMMAND_CLOSE_BELOW))
	popup.add_item("Close All", COMMAND_CLOSE_ALL, shortcut_get_accel(COMMAND_CLOSE_ALL))

func _gui_input(event: InputEvent) -> void:
	if not event.is_pressed() or event.is_echo(): return
	if event is InputEventMouseButton:
		var item: TreeItem = get_item_at_position(event.position)
		if not item: return
		
		if event.button_index == MOUSE_BUTTON_MIDDLE:
			item.select(0)
			close_item(item)
			accept_event()
		
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			item.select(0)
			accept_event()
			popup.position = get_viewport().position + Vector2i(event.global_position)
			popup.popup()
			

func _on_popup_menu_index_pressed(index: int) -> void:
	match index:
		COMMAND_SAVE:
			save_item(get_selected())
		COMMAND_SAVE_AS:
			save_item_as(get_selected())
		COMMAND_CLOSE:
			close_item(get_selected())
		COMMAND_CLOSE_OTHERS:
			close_items_except([get_selected()])
		COMMAND_CLOSE_BELOW:
			close_items_except(get_root().get_chilren().slice(0, get_selected().get_index()))
		COMMAND_CLOSE_ALL:
			close_items_except()

func close_items_except(items_staying: Array[TreeItem] = []) -> void:
	for item: TreeItem in get_root().get_children():
		if item in items_staying: continue
		close_item(item)


#endregion

#region Drag&Drop

func import_files(files: Array) -> void:
	for file in files:
		if not file is String: continue
		if ResourceLoader.exists(file, "RationalComponent"):
			cache.load_root_data(file)


func move_item(to_position: Vector2, item: TreeItem) -> void:
	if not item: return
	var location_item: TreeItem = get_item_at_position(to_position)
	if not location_item:
		return
	
	var root: TreeItem = get_root()
	var children: Array[TreeItem] = root.get_children()

	children[location_item.get_index()] = item
	children[item.get_index()] = location_item
	
	for child: TreeItem in children:
		root.remove_child(child)
	
	for child: TreeItem in children:
		root.add_child(child)


func _can_drop_data(at_position: Vector2, data: Variant) -> bool:
	if data is Dictionary:
		match data.get("type", ""):
			"files":
				return true
			"item" when data.get("source") == self:
				return true
	
	return false


func _drop_data(at_position: Vector2, data: Variant) -> void:
	if data is Dictionary:
		match data.get("type", ""):
			"files":
				import_files(data.get("files", []))
			"item":
				move_item(at_position, data.item)

# File dock format...
# { "type": "files", "files": ["res://BitMap.tres"], "from": @Tree@5673:<Tree#495833867875> }
func _get_drag_data(at_position: Vector2) -> Variant:
	var item: TreeItem = get_item_at_position(at_position)
	if not item:
		return null
	var button: Button = Button.new()
	button.text = item.get_text(0)
	button.icon = item.get_icon(0)
	button.modulate.a = 0.65
	set_drag_preview(button)
	return {type = "item", item = item, source = self}

#endregion 
