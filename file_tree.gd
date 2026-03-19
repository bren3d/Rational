@tool
extends Tree

const BASE_FILE_NAMES: PackedStringArray = ["RationalComponent", "RationalTree"]
var base_script_paths: PackedStringArray


var popup_menu: PopupMenu
enum {MENU_INDEX_RENAME = 0, MENU_INDEX_DUPLICATE = 1, MENU_INDEX_DELETE = 3}

func _ready() -> void:
	if not Engine.is_editor_hint() or is_part_of_edited_scene():
		return

	theme = EditorInterface.get_editor_theme()

	item_selected.connect(_on_item_selected)
	item_mouse_selected.connect(_on_item_mouse_selected)
	item_activated.connect(_on_item_activated)
	item_edited.connect(_on_item_edited)
	
	var file_dock: FileSystemDock = EditorInterface.get_file_system_dock()
	file_dock.file_removed.connect(_on_file_removed)
	file_dock.files_moved.connect(_on_file_moved)

	EditorInterface.get_resource_filesystem().script_classes_updated.connect(populate_base_script_paths)
	# for keycode: Key in [KEY_MASK_CTRL | KEY_D, KEY_DELETE, KEY_F2]:

	popup_menu = PopupMenu.new()
	popup_menu.name = &"FileTreePopupMenu"
	popup_menu.theme = theme
	
	popup_menu.add_icon_item(get_theme_icon(&"Rename", &"EditorIcons"), "Rename...", MENU_INDEX_RENAME, KEY_F2)
	popup_menu.add_icon_item(get_theme_icon(&"Duplicate", &"EditorIcons"), "Duplicate...", MENU_INDEX_DUPLICATE, KEY_MASK_CTRL | KEY_D) # KEY_MASK_CTRL
	popup_menu.add_separator()
	popup_menu.add_icon_item(get_theme_icon(&"Remove", &"EditorIcons"), "Delete...", MENU_INDEX_DELETE, KEY_DELETE)
	popup_menu.id_pressed.connect(_on_popup_menu_id_pressed)
	add_child(popup_menu)

	build_list()


func populate_base_script_paths() -> void:
	base_script_paths.clear()
	var class_list:= ProjectSettings.get_global_class_list()
	for dict: Dictionary in class_list:
		if dict.class not in BASE_FILE_NAMES: continue
		base_script_paths.push_back(dict.path)


func _gui_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed: return
	for index: int in [MENU_INDEX_RENAME, MENU_INDEX_DUPLICATE, MENU_INDEX_DELETE]:
		if event.get_keycode_with_modifiers() == popup_menu.get_item_accelerator(index):
			_on_popup_menu_id_pressed(index)
			accept_event()


func build_list() -> void:
	var fs: EditorFileSystem = EditorInterface.get_resource_filesystem()
	while fs.is_scanning():
		await get_tree().process_frame

	create_item().set_text(0, "Root")
	printt("Created root: ", get_root().get_text(0))
	for file: String in get_typed_files(&"Resource", fs.get_filesystem()):
		add_file(file)


func add_file(file: String) -> TreeItem:
	if get_item(file):
		print_rich("[color=red]Error[/color]: File \"[color=yellow]%s[/color]\" already exists in Tree." % file)
		return get_item(file)

	var item: TreeItem = bind_file_item(file)
	item.set_editable(0, false)
	item.set_icon(0, EditorInterface.get_editor_theme().get_icon(&"BitMap", &"EditorIcons"))
	print("Added file:\t%s" % file)
	return item
	

## Updates tree item to input [param file]
func bind_file_item(file: String, item: TreeItem = create_item(get_root(), -1)) -> TreeItem:
	item.set_metadata(0, file)
	item.set_text(0, file.get_file().trim_suffix(".tres"))
	item.set_tooltip_text(0, "%s\nSize: %s" % [file.trim_prefix("res://"), String.humanize_size(FileAccess.open(file, FileAccess.READ).get_length())])
	return item


func _get_drag_data(at_position: Vector2) -> Variant:
	var item: TreeItem = get_item_at_position(at_position)
	if not item: return null

	var preview: Button = Button.new()
	preview.flat = true
	preview.icon = item.get_icon(0) if item.get_icon(0) else ThemeDB.fallback_icon
	preview.text = item.get_metadata(0).get_file()
	set_drag_preview(preview)

	return {"type": "files", "files": [item.get_metadata(0)], "from": self, "item": item}


# { "type": "files", "files": ["res://BitMap.tres"], "from": @Tree@5673:<Tree#495833867875> }
func _can_drop_data(at_position: Vector2, data: Variant) -> bool:
	if typeof(data) == TYPE_DICTIONARY:
		if data.get("from", null) == self:
			drop_mode_flags = DROP_MODE_INBETWEEN
			return true

		for file in data.get("files", []):
			if is_valid_file(file):
				return true


	return false


func _drop_data(at_position: Vector2, data: Variant) -> void:
	# print_rich("[center]DATA DROPPED[/center]")
	if typeof(data) != TYPE_DICTIONARY: return
	
	if data.get("item", null) is TreeItem:
		if get_item_at_position(at_position):
			data.item.call(&"move_after" if get_drop_section_at_position(at_position) > 0 else &"move_before", get_item_at_position(at_position))
		return


	for file in data.get("files", []):
		if is_valid_file(file): add_file(file)


func _on_item_selected() -> void:
	pass


func _on_item_mouse_selected(mouse_position: Vector2, mouse_button_index: int) -> void:
	# printt("Item Selected(Mouse) -> ", get_selected().get_text(0) if get_selected() else "None selected...")
	
	if (mouse_button_index & MOUSE_BUTTON_RIGHT):
		popup_menu.position = DisplayServer.mouse_get_position()
		popup_menu.show()

	elif mouse_button_index & MOUSE_BUTTON_LEFT:
		if has_meta(&"selected") and get_meta(&"selected") == get_selected():
			edit_selected(true)
	

func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		for index: int in [MENU_INDEX_RENAME, MENU_INDEX_DUPLICATE, MENU_INDEX_DELETE]:
			if event.get_keycode_with_modifiers() == popup_menu.get_item_accelerator(index):
				_on_popup_menu_id_pressed(index)
	

func _on_item_activated() -> void:
	var item: TreeItem = get_selected()
	print("Item Activated..." + item.get_text(0))

func _on_add_pressed() -> void:
	print("Add pressed...")

func _on_load_pressed() -> void:
	print("Load pressed...")


func _on_file_removed(file: String) -> void:
	var item: TreeItem = get_item(file)
	if item: item.free()
		

func _on_popup_menu_id_pressed(index: int) -> void:
	printt(popup_menu.get_item_text(index), " pressed!")
	match index:
		MENU_INDEX_RENAME:
			edit_selected(true)
		MENU_INDEX_DUPLICATE:
			confirm_duplicate(get_selected())
		MENU_INDEX_DELETE:
			confirm_delete(get_selected())


func _on_item_edited() -> void:
	var item: TreeItem = get_edited()
	var new_file: String = item.get_text(0)
	printt("Item Edited ->", new_file)
	
	var old_file: String = item.get_metadata(0).get_file().trim_suffix(".tres")
	var new_file_path: String = item.get_metadata(0).get_base_dir() + new_file + ".tres"

	if old_file != new_file and is_valid_rename(new_file_path):
		if DirAccess.rename_absolute(item.get_metadata(0), new_file_path) == OK:
			print("FILE PATH CHANGED: %s -> %s" % [item.get_metadata(0), new_file_path])
			bind_file_item(new_file_path, item, )
			EditorInterface.get_resource_filesystem().scan()


	else:
		item.set_text(0, old_file)


func is_valid_rename(file: String) -> bool:
	if not file:
		printerr("Empty parameter 'file' entered in func 'is_valid_filename'")
		return false
	if not file.get_file().is_valid_filename():
		printerr("Invalid Filename Submitted! -> %s" % file.get_file())
		return false
	if FileAccess.file_exists(file):
		return false

	return true


func _on_file_moved(old_file: String, new_file: String) -> void:
	printt("\"_on_file_moved\" called: ", old_file, " -> ", new_file)
	if not is_valid_file(new_file): return
	var item: TreeItem = get_item(old_file)
	if item: bind_file_item(new_file, item)


func duplicate_item(to_path: String, item_path: String) -> void:
	to_path = item_path.get_base_dir().path_join(to_path)
	if DirAccess.copy_absolute(item_path, to_path) != OK:
		print("Error duplicating file: %s -> %s" % [item_path, to_path])
		return

	var item: TreeItem = add_file(to_path)
	EditorInterface.get_resource_filesystem().scan()

	set_selected.call_deferred(item, 0)
	ensure_cursor_is_visible.call_deferred()
	grab_focus.call_deferred()


func delete_item(file: String) -> void:
	assert(Engine.is_editor_hint(), "Deleting file outside of editor...")
	DirAccess.remove_absolute(file)
	EditorInterface.get_resource_filesystem().scan()


func confirm_duplicate(item: TreeItem) -> void:
	var dialog: ConfirmationDialog = ConfirmationDialog.new()
	dialog.title = "Duplicate..."
	dialog.dialog_text = "Please enter a name for duplicate file."

	var line_edit: LineEdit = LineEdit.new()
	line_edit.text = item.get_text(0) + ".tres"
	line_edit.visibility_changed.connect(line_edit.grab_focus, CONNECT_DEFERRED)
	line_edit.select_all_on_focus = true
	line_edit.text_submitted.connect(duplicate_item.bind(item.get_metadata(0)))

	dialog.register_text_enter(line_edit)
	dialog.print_tree_pretty()
	dialog.add_child(line_edit)
	dialog.confirmed.connect(dialog.emit_signal.bind("close_requested"), CONNECT_DEFERRED)
	dialog.close_requested.connect(dialog.queue_free, CONNECT_DEFERRED)

	EditorInterface.popup_dialog_centered(dialog)


func confirm_delete(item: TreeItem) -> void:
	var dialog: ConfirmationDialog = ConfirmationDialog.new()
	dialog.ok_button_text = "Remove"
	dialog.dialog_text = "Remove the selected files from the project? (Cannot be undone.)"
	dialog.confirmed.connect(delete_item.bind(item.get_metadata(0)))
	dialog.confirmed.connect(item.free, CONNECT_DEFERRED)
	dialog.confirmed.connect(dialog.emit_signal.bind("close_requested"), CONNECT_DEFERRED)
	dialog.close_requested.connect(dialog.queue_free, CONNECT_DEFERRED)
	EditorInterface.popup_dialog_centered(dialog)


func is_valid_file(file: String) -> bool:
	if not FileAccess.file_exists(file):
		return false
	
	for file_path: String in ResourceLoader.get_dependencies(file):
		if file_path.get_file() in BASE_FILE_NAMES:

			return true
	return false


func get_item(file: String) -> TreeItem:
	for item: TreeItem in get_root().get_children():
		if item.get_metadata(0) == file: return item
	return null


func get_typed_files(type_name: StringName = &"", dir: EditorFileSystemDirectory = EditorInterface.get_resource_filesystem().get_filesystem()) -> PackedStringArray:
	var files: PackedStringArray

	for i: int in dir.get_file_count():
		if not type_name or dir.get_file_type(i) == type_name:
			files.push_back(dir.get_file(i))

	for i: int in dir.get_subdir_count():
		files.append_array(get_typed_files(type_name, dir.get_subdir(i)))

	return files


func _get_file_icon(file: String) -> Texture2D:
	return ThemeDB.fallback_icon


func get_file_size(file_path: String) -> int:
	var file_access: FileAccess = FileAccess.open(file_path, FileAccess.READ)
	return FileAccess.open(file_path, FileAccess.READ).get_length()


func _set(property: StringName, value: Variant) -> bool:
	match property:
		&"drop_mode_flags":
			print_rich("Setting [b]DROP FLAGS[/b]\t->\t", value)
	return false
