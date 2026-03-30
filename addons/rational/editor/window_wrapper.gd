@tool
extends Control

const MainEditor := preload("main.gd")

var window: Window

var main_window_parent: MarginContainer

var main: MainEditor

func _init() -> void:
	name = &"Rational"
	
	hide()
	
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	
	window = Window.new()
	window.visible = false
	window.title = "Rational Editor - Godot Engine"
	window.wrap_controls = true
	window.min_size = Vector2i(600, 350)
	window.transient = true
	
	var panel: Panel = Panel.new()
	panel.add_theme_stylebox_override(&"panel", EditorInterface.get_editor_theme().get_stylebox(&"PanelForeground", &"EditorStyles"))
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	
	main_window_parent= MarginContainer.new()
	main_window_parent.theme_type_variation = &"MarginContainer4px"
	main_window_parent.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.add_child(main_window_parent)
	
	window.add_child(panel)
	add_child(window)
	
	window.close_requested.connect(close_window)


func _ready() -> void:
	window.size = size
	window.position = get_screen_position()
	
	if Engine.has_singleton(&"Rational"):
		main = Engine.get_singleton(&"Rational").editor
		main.make_floating_button.pressed.connect(open_window)
		add_child(main)


func open_window() -> void:
	main.reparent(main_window_parent, false)
	EditorInterface.set_main_screen_editor("2D")
	main.make_floating_button.hide()
	window.show()

func close_window() -> void:
	window.hide()
	main.reparent(self, false)
	main.make_floating_button.show()


func make_visible(is_visible: bool) -> void:
	if window.visible:
		window.grab_focus()
		return
	
	visible = is_visible
	
	if visible:
		EditorInterface.set_main_screen_editor("Rational")
