@tool


static func get_plugin() -> EditorPlugin:
	return Engine.get_singleton(&"Rational")

static func get_cache() -> Object:
	return get_plugin().cache

static func get_class_data() -> Object:
	return get_cache().class_data

static func get_main_editor() -> Object:
	return get_plugin().editor

static func get_action_handle() -> Object:
	return get_plugin().action_handle

static func get_undo_redo() -> Object:
	return EditorInterface.get_editor_undo_redo()

static func toast(message: String, severity: EditorToaster.Severity = 0, tooltip: String = "") -> void:
	EditorInterface.get_editor_toaster().push_toast(message, severity, tooltip)

static func comp_get_icon(component: Object) -> Texture2D:
	return get_class_data().comp_get_icon(component)

static func comp_get_class(component: Object) -> StringName:
	return get_class_data().comp_get_class(component)

static func class_get_script(_class: StringName) -> Script:
	return get_class_data().class_get_script(_class)

static func instantiate_class(_class: StringName) -> Object:
	return get_class_data().instantiate_class(_class)

static func instantiate_path(script_path: String) -> Object:
	return get_class_data().instantiate_path(script_path)

static func class_is_valid(_class: StringName) -> bool:
	return  get_class_data().class_is_valid(_class)

## Verifies the script inherets from [RationalComponent].
static func script_path_is_valid(path: String) -> bool:
	return get_class_data().script_path_is_valid(path)

#static func create_comp

#region Theme

static func get_icon(icon: StringName, theme_type: StringName = &"EditorIcons") -> Texture2D:
	return EditorInterface.get_editor_theme().get_icon(icon, theme_type)

static func get_font(name: StringName, theme_type: StringName = &"EditorFonts") -> Font:
	return EditorInterface.get_editor_theme().get_font(name, theme_type)

static func get_stylebox(name: StringName, theme_type: StringName = &"EditorStyles") -> StyleBox:
	return EditorInterface.get_editor_theme().get_stylebox(name, theme_type)

static func get_icon_max_width() -> int:
	return int(16.0 * EditorInterface.get_editor_scale())

#endregion Theme

#region Helpers

static func generate_unique_name(initial_name: String, name_list: PackedStringArray) -> String:
	if not initial_name: 
		return ""
	
	var base_name: String = initial_name
	var result: String = initial_name

	var i: int = 0
	while (i + 1) < result.length() and result.right(i + 1).is_valid_int():
		i += 1
	
	if i > 0:
		base_name = result.left(result.length() - i)
		i = result.right(i).to_int()
	
	while result in name_list:
		i += 1
		result = base_name + str(i)
	
	return result

static func add_menu_item(menu: PopupMenu, label: String, icon: StringName = &"", shortcut: StringName = "", metadata: Variant = null, id: int = -1) -> void:
	menu.add_item(label, id)
	if icon:
		menu.set_item_icon(menu.item_count - 1, get_icon(icon))
	if shortcut:
		menu.set_item_shortcut(menu.item_count - 1, get_shortcut(shortcut))
		menu.set_item_accelerator(menu.item_count - 1, get_accel(shortcut))
	if metadata != null:
		menu.set_item_metadata(menu.item_count - 1, metadata)

static func shortcut_get_accel(shortcut: Shortcut) -> Key:
	if shortcut:
		for event: InputEvent in (shortcut.events if shortcut else []):
			if event is InputEventKey:
				return event.get_keycode_with_modifiers()
	return KEY_NONE

static func get_accel(name: String) -> Key:
	return shortcut_get_accel(get_shortcut(name))

static func get_shortcut(name: StringName) -> Shortcut:
	match name:
		&"rename": 
			return EditorInterface.get_editor_settings().get_shortcut("scene_tree/rename")
		&"save": 
			return EditorInterface.get_editor_settings().get_shortcut("script_editor/save")
		&"save_as": 
			return EditorInterface.get_editor_settings().get_shortcut("script_editor/save_as")
		&"close", &"close_file": 
			return EditorInterface.get_editor_settings().get_shortcut("script_editor/close_file")
		&"close_others", &"close_other_tabs": 
			return EditorInterface.get_editor_settings().get_shortcut("script_editor/close_other_tabs")
		&"close_below", &"close_tabs_below": 
			return EditorInterface.get_editor_settings().get_shortcut("script_editor/close_tabs_below")
		&"close_all": 
			return EditorInterface.get_editor_settings().get_shortcut("script_editor/close_all")
		&"next_file": 
			return EditorInterface.get_editor_settings().get_shortcut("script_editor/next_script")
		&"prev_file": 
			return EditorInterface.get_editor_settings().get_shortcut("script_editor/prev_script")
		&"find": 
			return EditorInterface.get_editor_settings().get_shortcut("script_editor/find")
		&"find_next": 
			return EditorInterface.get_editor_settings().get_shortcut("script_editor/find_next")
		&"find_previous": 
			return EditorInterface.get_editor_settings().get_shortcut("script_editor/find_previous")
		&"make_floating": 
			return EditorInterface.get_editor_settings().get_shortcut("script_editor/make_floating")
		&"history_previous": 
			return EditorInterface.get_editor_settings().get_shortcut("script_editor/history_previous")
		&"history_next": 
			return EditorInterface.get_editor_settings().get_shortcut("script_editor/history_next")
		&"new": 
			return EditorInterface.get_editor_settings().get_shortcut("script_editor/new")
		&"change_type", &"change_node_type", &"change_component_type": 
			return EditorInterface.get_editor_settings().get_shortcut("scene_tree/change_node_type")
		&"save_as_root", &"save_comp_as_root", &"as_root": 
			return EditorInterface.get_editor_settings().get_shortcut("scene_tree/save_branch_as_scene")
		&"cut":
			return EditorInterface.get_editor_settings().get_shortcut("scene_tree/cut_node")
		&"copy":
			return EditorInterface.get_editor_settings().get_shortcut("scene_tree/copy_node")
		&"paste":
			return EditorInterface.get_editor_settings().get_shortcut("scene_tree/paste_node")
		&"duplicate":
			return EditorInterface.get_editor_settings().get_shortcut("scene_tree/duplicate")
		&"reparent":
			return EditorInterface.get_editor_settings().get_shortcut("scene_tree/reparent")
		&"reparent_to_new_node", &"reparent_to_new":
			return EditorInterface.get_editor_settings().get_shortcut("scene_tree/reparent_to_new_node")
		&"delete":
			return EditorInterface.get_editor_settings().get_shortcut("scene_tree/delete")
		&"delete_no_confirm":
			return EditorInterface.get_editor_settings().get_shortcut("scene_tree/delete_no_confirm")
		&"make_root", &"create_root": 
			return EditorInterface.get_editor_settings().get_shortcut("scene_tree/make_root")
		&"add_child_node", &"add_child":
			return EditorInterface.get_editor_settings().get_shortcut("scene_tree/add_child_node")
		&"instantiate_child", &"instantiate_component", &"instantiate_root":
			return EditorInterface.get_editor_settings().get_shortcut("scene_tree/instantiate_scene")
		&"toggle_grid": 
			return EditorInterface.get_editor_settings().get_shortcut("canvas_item_editor/toggle_grid")
		&"use_grid_snap": 
			return EditorInterface.get_editor_settings().get_shortcut("canvas_item_editor/use_grid_snap")
		&"frame_selection": 
			return EditorInterface.get_editor_settings().get_shortcut("canvas_item_editor/frame_selection")
		&"center_selection": 
			return EditorInterface.get_editor_settings().get_shortcut("canvas_item_editor/center_selection")
		&"cancel_transform": 
			return EditorInterface.get_editor_settings().get_shortcut("canvas_item_editor/cancel_transform")
		&"zoom_minus": 
			return EditorInterface.get_editor_settings().get_shortcut("canvas_item_editor/zoom_minus")
		&"zoom_plus": 
			return EditorInterface.get_editor_settings().get_shortcut("canvas_item_editor/zoom_plus")
		&"toggle_files_panel":
			return EditorInterface.get_editor_settings().get_shortcut("script_editor/toggle_files_panel")
		&"show_in_filesystem", &"show_in_file_system":
			return EditorInterface.get_editor_settings().get_shortcut("script_editor/show_in_file_system")
		_ when "zoom_percent".is_subsequence_of(name):
			return EditorInterface.get_editor_settings().get_shortcut("canvas_item_editor/%s" % name)
	push_warning("No shortcut found: '%s'" % name)
	return null

#endregion Helpers
