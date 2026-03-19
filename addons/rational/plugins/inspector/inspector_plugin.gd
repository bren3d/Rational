@tool
extends EditorInspectorPlugin

const Cache:= preload("../../data/cache.gd")

var cache: Cache

var is_editing_tree: bool = false

func _init() -> void:
	EditorInterface.get_inspector().edited_object_changed.connect(_on_edited_object_changed)
	EditorInterface.get_inspector().property_edited.connect(_on_property_edited)
	EditorInterface.get_inspector().resource_selected.connect(_on_resource_selected)

func _on_resource_selected(resource: Resource, path: String) -> void:
	print("Resource Selected: %s | Path: %s" % [resource, path])

func set_cache(val: Cache) -> void:
	cache = val

func _can_handle(object: Object) -> bool:
	return object is RationalTree


func _on_edited_object_changed():
	is_editing_tree = EditorInterface.get_inspector().get_edited_object() is RationalTree


func _on_property_edited(property: StringName) -> void:
	if is_editing_tree and property == &"root":
		cache.add_root(EditorInterface.get_inspector().get_edited_object().root)


func create_button() -> Control:
	var button: Button = Button.new()
	button.theme = EditorInterface.get_editor_theme()
	button.theme_type_variation = &"InspectorActionButton"
	button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	return button


func create_margin_container(child_control: Control = null, margins: Vector2 = Vector2(4, 4), ) -> MarginContainer:
	margins * EditorInterface.get_editor_scale()
	var margin_container := MarginContainer.new()
	margin_container.add_theme_constant_override("margin_left", margins.x)
	margin_container.add_theme_constant_override("margin_right", margins.x)
	margin_container.add_theme_constant_override("margin_top", margins.y)
	margin_container.add_theme_constant_override("margin_bottom", margins.y)
	if child_control: margin_container.add_child(child_control)
	return margin_container


func _parse_category(object: Object, category: String) -> void:
	if category != "rational_tree.gd": return
	
	var button: Button = create_button()
	button.text = "Edit Behavior Tree"
	button.tooltip_text = "Switch to the behavior tree editor tab."
	button.icon = button.get_theme_icon(&"ExternalLink", &"EditorIcons")
	button.pressed.connect(Engine.get_meta(&"Main").edit_tree.bind(object))
	
	add_custom_control(create_margin_container(button))
