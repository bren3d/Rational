@tool
extends RefCounted

static func populate() -> void:
	var es: EditorSettings = EditorInterface.get_editor_settings()
	var paths := get_shortcut_paths()
	
	for name: String in paths:
		var setting_path: String = "rational/shortcuts/%s" % name
		
		var shortcut: Shortcut = es.get_shortcut(paths[name]) if es.has_shortcut(paths[name]) else Shortcut.new()
		if not ProjectSettings.has_setting(setting_path):
			ProjectSettings.set_setting(setting_path , shortcut)
		
		ProjectSettings.add_property_info({
			name = setting_path,
			type = TYPE_OBJECT,
			hint = PROPERTY_HINT_RESOURCE_TYPE,
			hint_string = "Shortcut",
			})
		ProjectSettings.set_initial_value(setting_path, shortcut)
	
	print("Rational Project Settings Populated.")




static func get_shortcut_list() -> Dictionary[String, Shortcut]:
	var result:Dictionary[String, Shortcut]
	var es: EditorSettings = EditorInterface.get_editor_settings()
	#for path: String in get_shortcut_paths():
		#var sc: Shortcut = editor_settings.get_shortcut(path)
		#if sc:
			#result[path] = editor_settings.get_shortcut(path)
	return result



static func get_shortcut_paths() -> Dictionary[String, String]:
	return {
		"rename": "scene_tree/rename",
		"save": "script_editor/save",
		"save_as": "script_editor/save_as",
		"close_file": "script_editor/close_file",
		"close_other_tabs": "script_editor/close_other_tabs",
		"close_tabs_below": "script_editor/close_tabs_below",
		"close_all": "script_editor/close_all",
		"next_file": "script_editor/next_script",
		"prev_file": "script_editor/prev_script",
		"find": "script_editor/find",
		"find_next": "script_editor/find_next",
		"find_previous": "script_editor/find_previous",
		"make_floating": "script_editor/make_floating",
		"history_previous": "script_editor/history_previous",
		"history_next": "script_editor/history_next",
		"new": "script_editor/new",
		"change_component_type": "scene_tree/change_node_type",
		"make_root": "scene_tree/make_root",
		"toggle_grid": "canvas_item_editor/toggle_grid",
		"use_grid_snap": "canvas_item_editor/use_grid_snap",
		"frame_selection": "canvas_item_editor/frame_selection",
		"center_selection": "canvas_item_editor/center_selection",
		"cancel_transform": "canvas_item_editor/cancel_transform",
		"zoom_minus": "canvas_item_editor/zoom_minus",
		"zoom_plus": "canvas_item_editor/zoom_plus",
		"zoom_25_percent": "canvas_item_editor/zoom_25_percent",
		"zoom_50_percent": "canvas_item_editor/zoom_50_percent",
		"zoom_100_percent": "canvas_item_editor/zoom_100_percent",
		"zoom_200_percent": "canvas_item_editor/zoom_200_percent",
		"zoom_400_percent": "canvas_item_editor/zoom_400_percent",
		"zoom_800_percent": "canvas_item_editor/zoom_800_percent",
		"zoom_1600_percent": "canvas_item_editor/zoom_1600_percent",
		"zoom_3.125_percent": "canvas_item_editor/zoom_3.125_percent",
		"zoom_6.25_percent": "canvas_item_editor/zoom_6.25_percent",
		"zoom_12.5_percent": "canvas_item_editor/zoom_12.5_percent",
	}

static func shortcut_get_default(name: StringName) -> Shortcut:
	return EditorInterface.get_editor_settings().get_shortcut(get_shortcut_paths().get(name, ""))
