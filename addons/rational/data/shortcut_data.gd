@tool
extends RefCounted
##


#region Shortcut Names

const RENAME: StringName = &"rename"
const SAVE: StringName = &"save"
const SAVE_AS: StringName = &"save_as"
const CLOSE_FILE: StringName = &"close_file"
const CLOSE_OTHER_TABS: StringName = &"close_other_tabs"
const CLOSE_TABS_BELOW: StringName = &"close_tabs_below"
const CLOSE_ALL: StringName = &"close_all"
const TOGGLE_GRID: StringName = &"toggle_grid"
const USE_GRID_SNAP: StringName = &"use_grid_snap"
const FRAME_SELECTION: StringName = &"frame_selection"
const CENTER_SELECTION: StringName = &"center_selection"
const CANCEL_TRANSFORM: StringName = &"cancel_transform"
const ZOOM_MINUS: StringName = &"zoom_minus"
const ZOOM_PLUS: StringName = &"zoom_plus"
const CHANGE_TYPE: StringName = &"change_type"
const MAKE_ROOT: StringName = &"make_root"

const ZOOM_PERCENTS: PackedStringArray = ["zoom_3.125_percent", "zoom_6.25_percent", "zoom_12.5_percent", "zoom_25_percent", "zoom_50_percent", 
		"zoom_100_percent", "zoom_200_percent", "zoom_400_percent", "zoom_800_percent", "zoom_1600_percent"]

#endregion Shortcut Names

#@export_tool_button("dfk", "Zoom")
#var djkf

var data: Dictionary[StringName, Shortcut]

func _init() -> void:
	update()
	EditorInterface.get_editor_settings().settings_changed.connect(update)

## Blank names/names with no shortcut in [param name_list] will add a separator.
func add_items(menu: PopupMenu, name_list: Array[StringName]) -> void:
	for name: StringName in name_list:
		if not has_shortcut(name):
			menu.add_separator(name)
		else:
			add_item(menu, name)

## Adds item entry to [parem menu] for [parem name].
func add_item(menu: PopupMenu , name: StringName, metadata: Variant = null, id: int = -1) -> void:
	id = menu.item_count if id < 0 else id
	
	if has_icon(name):
		menu.add_icon_item(get_icon(name), get_label(name), id)
	else:
		menu.add_item(get_label(name), id)
		
	menu.add_shortcut(get_shortcut(name), id)
	if metadata != null:
		menu.set_item_metadata(id, metadata)

#func menu_get_shortcuts(menu: PopupMenu) -> Dictionary[Shortcut, ]

func get_shortcut(name: StringName) -> Shortcut:
	return data.get(name)

func get_accel(name: StringName) -> Key:
	return shortcut_get_accel(get_shortcut(name))

func get_icon(name: StringName) -> Texture2D:
	return EditorInterface.get_editor_theme().get_icon(get_icon_name(name), &"EditorIcons")

func has_shortcut(name: StringName) -> bool:
	return get_shortcut(name) != null

func has_accel(name: StringName) -> bool:
	return get_accel(name) != KEY_NONE

func has_icon(name: StringName) -> bool:
	return get_icon_name(name) != &"" and get_icon(name) != null

func get_data(name: StringName) -> Dictionary[StringName, Variant]:
	return {
		name = name,
		label = get_label(name),
		shortcut = get_shortcut(name),
		icon = get_icon(name),
		accel = get_accel(name),
		}

func get_zoom_percent_shortcuts() -> Dictionary[Shortcut, float]:
	var result: Dictionary[Shortcut, float]
	for name: String in ZOOM_PERCENTS:
		result[get_shortcut(name)] = name.get_slice("_", 1).to_float()
	return result


func get_shortcut_list() -> Array[StringName]:
	var result: Array[StringName] = [RENAME, SAVE, SAVE_AS, CLOSE_FILE, CLOSE_OTHER_TABS, CLOSE_TABS_BELOW, 
			CLOSE_ALL, TOGGLE_GRID, USE_GRID_SNAP, FRAME_SELECTION, CENTER_SELECTION, CANCEL_TRANSFORM, ZOOM_MINUS, ZOOM_PLUS, CHANGE_TYPE]
	for sc: String in ZOOM_PERCENTS:
		result.push_back(sc)
	return result

func shortcut_get_accel(shortcut: Shortcut) -> Key:
	for event: InputEvent in (shortcut.events if shortcut else []):
		if event is InputEventKey:
			return event.get_keycode_with_modifiers()
	return KEY_NONE

func get_label(name: StringName) -> String:
	match name:
		SAVE_AS: return "Save As..."
		CLOSE_FILE: return "Close"
		CLOSE_OTHER_TABS: return "Close Others"
		CLOSE_TABS_BELOW: return "Close Below"
		ZOOM_MINUS: return "Zoom Out"
		ZOOM_PLUS: return "Zoom In"
	return name.capitalize()
	
func get_path(name: StringName) -> String:
	match name:
		RENAME: return "scene_tree/rename"
		SAVE: return "script_editor/save"
		SAVE_AS: return "script_editor/save_as"
		CLOSE_FILE: return "script_editor/close_file"
		CLOSE_OTHER_TABS: return "script_editor/close_other_tabs"
		CLOSE_TABS_BELOW: return "script_editor/close_tabs_below"
		CLOSE_ALL: return "script_editor/close_all"
		TOGGLE_GRID: return "canvas_item_editor/toggle_grid"
		USE_GRID_SNAP: return "canvas_item_editor/use_grid_snap"
		FRAME_SELECTION: return "canvas_item_editor/frame_selection"
		CENTER_SELECTION: return "canvas_item_editor/center_selection"
		CANCEL_TRANSFORM: return "canvas_item_editor/cancel_transform"
		ZOOM_MINUS: return "canvas_item_editor/zoom_minus"
		ZOOM_PLUS: return "canvas_item_editor/zoom_plus"
		CHANGE_TYPE: return "scene_tree/change_node_type"
		MAKE_ROOT: return "scene_tree/make_root"

		_ when name in ZOOM_PERCENTS: return "canvas_item_editor/%s" % name
	return ""

func get_icon_name(name: StringName) -> StringName:
	match name:
		RENAME: return &"Rename"
		SAVE: return &"Save"
		TOGGLE_GRID: return &"GridToggle"
		USE_GRID_SNAP: return &"SnapGrid"
		ZOOM_MINUS: return &"ZoomLess"
		ZOOM_PLUS: return &"ZoomMore"
		CHANGE_TYPE: return &"RotateLeft"
		MAKE_ROOT: return &"NewRoot"
	return &""



func update() -> void:
	for sc: StringName in get_shortcut_list():
		add_shortcut(sc, get_path(sc))

func add_shortcut(name: StringName, path: String) -> void:
	if not EditorInterface.get_editor_settings().has_shortcut(path):
		printerr("Invalid shortcut '%s'" % path)
		return
	
	data[name] = EditorInterface.get_editor_settings().get_shortcut(path)
