@tool
extends "inspector_plugin.gd"


func _can_handle(object: Object) -> bool:
	return object is RationalComponent


func _parse_begin(object: Object) -> void:
	if not Engine.has_meta(&"Main"):
		print_rich("[color=red]ERROR[/color]: Engine does not have meta \"[color=red]Main[/color]\"")
		return

	var button: Button = create_button()
	button.text = "Edit Behavior Tree"
	button.tooltip_text = "Switch to the behavior tree editor tab."
	button.icon = button.get_theme_icon(&"ExternalLink", &"EditorIcons")
	button.pressed.connect(Engine.get_meta(&"Main").edit_tree.bind(object))
	var margin: MarginContainer = create_margin_container()
	margin.add_child(button)
	add_custom_control(margin)
	
	
func _parse_property(object: Object, type: Variant.Type, name: String, hint_type: PropertyHint, hint_string: String, usage_flags: int, wide: bool) -> bool:
	
	if name != "actor":
		return false
		
	if not Engine.has_meta(&"Main"):
		print_rich("[color=red]ERROR[/color]: Engine does not have meta \"[color=red]Main[/color]\"")
		return false

	
	return false

# func _on