@tool
extends RefCounted

const SUCCESS_COLOR := Color("#07783a")
const NORMAL_COLOR := Color("#15181e")
const FAILURE_COLOR := Color("#82010b")
const RUNNING_COLOR := Color("#c29c06")

var panel_normal: StyleBoxFlat
var panel_success: StyleBoxFlat
var panel_failure: StyleBoxFlat
var panel_running: StyleBoxFlat

var titlebar_normal: StyleBoxFlat
var titlebar_success: StyleBoxFlat
var titlebar_failure: StyleBoxFlat
var titlebar_running: StyleBoxFlat


func _init() -> void:
	var theme: Theme = EditorInterface.get_editor_theme()
	titlebar_normal = theme.get_stylebox(&"titlebar", &"GraphNode").duplicate()

	titlebar_success = titlebar_normal.duplicate()
	titlebar_failure = titlebar_normal.duplicate()
	titlebar_running = titlebar_normal.duplicate()
	
	titlebar_success.bg_color = SUCCESS_COLOR
	titlebar_failure.bg_color = FAILURE_COLOR
	titlebar_running.bg_color = RUNNING_COLOR
	
	titlebar_success.border_color = SUCCESS_COLOR
	titlebar_failure.border_color = FAILURE_COLOR
	titlebar_running.border_color = RUNNING_COLOR
	
	panel_normal = theme.get_stylebox(&"panel", &"GraphNode").duplicate()
	panel_success = theme.get_stylebox(&"panel_selected", &"GraphNode").duplicate()

	panel_failure = panel_success.duplicate()
	panel_running = panel_success.duplicate()
	
	panel_success.border_color = SUCCESS_COLOR
	panel_failure.border_color = FAILURE_COLOR
	panel_running.border_color = RUNNING_COLOR
