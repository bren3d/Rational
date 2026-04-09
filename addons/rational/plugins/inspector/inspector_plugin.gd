@tool
extends EditorInspectorPlugin

const Util := preload("../../util.gd")
const Cache:= preload("../../data/cache.gd") # TBR

var cache: Cache

func _init() -> void:
	cache = Util.get_cache()

# TODO: Only handle rational components.
func _can_handle(object: Object) -> bool:
	return object is RationalTree or object is RationalComponent

# TODO: Prevent creating buttons for components that are not a root.
func _parse_begin(object: Object) -> void:
	if object is RationalComponent:
		var button: Button = create_button()
		button.pressed.connect(cache.edit_root.bind(object))

func _parse_property(object: Object, type: Variant.Type, name: String, hint_type: PropertyHint, hint_string: String, usage_flags: int, wide: bool) -> bool:
	if object is RationalTree and name == "root":
		var button: Button = create_button()
		button.pressed.connect(_on_edit_pressed.bind(object, name))
		
		
		var picker:= create_picker(object, name, "Composite")
		
		return true
	
	return false

func _on_edit_pressed(object: Object, property: String = "") -> void:
	cache.edit_root(object.get(property))

func _on_picker_changed(res: Resource, editor_property: EditorProperty) -> void:
	editor_property.emit_changed(editor_property.get_edited_property(), res)
	if res:
		cache.edit_root(res) 


func _on_picker_selected(resource: Resource, inspect: bool, editor_property: EditorProperty) -> void:
	var picker: EditorResourcePicker = editor_property.get_child(-1)
	editor_property.select(- int(editor_property.is_selected()))
	if inspect:
		editor_property.resource_selected.emit("root", resource)
	
	cache.edit_root(resource) 

func _on_editor_property_changed(property: StringName, value: Variant, field: StringName, changing: bool, picker: EditorResourcePicker) -> void:
	picker.set_block_signals(true)
	picker.set_edited_resource(value)
	picker.set_block_signals(false)

#region GUI

func create_picker(object: Object, property: String, base_type: String) -> EditorResourcePicker:
	var picker: EditorResourcePicker = EditorResourcePicker.new()
	picker.base_type = base_type
	picker.theme_type_variation = &"EditorInspectorButton"
	picker.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	picker.edited_resource = object.get(property)
	picker.focus_mode = Control.FOCUS_ALL
	picker.toggle_mode = true

	var eprop: EditorProperty = EditorProperty.new()
	eprop.use_folding = true
	eprop.set_object_and_property(object, property)
	eprop.label = property.capitalize()
	eprop.add_child(picker)
	eprop.add_focusable(picker)
	
	#eprop.selected.connect(_on_selected)
	
	eprop.property_changed.connect(_on_editor_property_changed.bind(picker))
	
	picker.resource_changed.connect(_on_picker_changed.bind(eprop))
	picker.resource_selected.connect(_on_picker_selected.bind(eprop))
	
	add_property_editor(property, eprop)
	return picker


func create_button() -> Button:
	var button: Button = Button.new()
	button.theme_type_variation = &"InspectorActionButton"
	button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	button.text = "Edit Tree"
	button.icon = Engine.get_singleton(&"Rational")._get_plugin_icon() if Engine.has_singleton(&"Rational") else \
			EditorInterface.get_editor_theme().get_icon(&"ExternalLink", &"EditorIcons")
	
	button.tooltip_text = "Switch to the behavior tree editor tab."
	
	add_custom_control(create_margin_container(button))
	return button


func create_margin_container(child_control: Control = null, margins: Vector2 = Vector2(4, 4), ) -> MarginContainer:
	margins *= EditorInterface.get_editor_scale()
	var margin_container := MarginContainer.new()
	margin_container.add_theme_constant_override("margin_left", margins.x)
	margin_container.add_theme_constant_override("margin_right", margins.x)
	margin_container.add_theme_constant_override("margin_top", margins.y)
	margin_container.add_theme_constant_override("margin_bottom", margins.y)
	if child_control: margin_container.add_child(child_control)
	return margin_container

#endregion GUI
