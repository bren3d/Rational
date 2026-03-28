@tool
extends EditorInspectorPlugin

const Cache:= preload("../../data/cache.gd")

var cache: Cache

var is_editing_component: bool = false
var is_editing_tree: bool = false

func set_cache(val: Cache) -> void:
	cache = val

func _can_handle(object: Object) -> bool:
	return object is RationalTree

func _parse_property(object: Object, type: Variant.Type, name: String, hint_type: PropertyHint, hint_string: String, usage_flags: int, wide: bool) -> bool:
	if type == TYPE_OBJECT and hint_type == PROPERTY_HINT_RESOURCE_TYPE and cache.class_extends_rational_component(hint_string):
		var button: Button = create_button()
		button.pressed.connect(_on_edit_tree_pressed.bind(object, name))
		if object is Node:
			if not object.tree_entered.is_connected(update_tree_path):
				object.tree_entered.connect(update_tree_path.bind(object, name))
		
		var picker:= create_picker(object, name, hint_string)
		
		return true
	
	#if is_editing_tree and name == "disabled":
		#for eprop: EditorProperty in EditorInterface.get_inspector().find_children("*", "EditorProperty", true, false):
			#if eprop.get_edited_property() != &"blackboard": continue
			#eprop.resource_selected.connect(func(p: String, res: Resource): print("Path: %s | Resource: %s" %[p, res]))
			#eprop.object_id_selected.connect(func(p: StringName, id: int): print("Path: %s | Resource: %s" %[p, id]))
		
	
	return false #type == TYPE_OBJECT and hint_string == ""

func update_node_path(node: Node, property: String) -> void:
	var data: RootData = cache.root_get_data(node.get(property))
	if data:
		data.set_meta(RootData.META_PATH, {path = node.owner.get_path_to(node), property = property})


func update_tree_path(tree: RationalTree, property: String = "root") -> void:
	if cache.has_root(tree.get(property)):
		cache.root_get_data(tree.get(property)).set_meta(RootData.META_PATH, {path = tree.owner.get_path_to(tree), property = property})

func _on_rational_tree_entered(tree: RationalTree) -> void:
	update_tree_path(tree)

func _on_edit_tree_button_pressed(tree: RationalTree) -> void:
	if not tree.tree_entered.is_connected(_on_rational_tree_entered):
		tree.tree_entered.connect(_on_rational_tree_entered, CONNECT_APPEND_SOURCE_OBJECT)
	update_tree_path(tree)
	if Engine.has_meta(&"Main"):
		Engine.get_meta(&"Main").edit_tree(tree) 


func _on_edit_component_button_pressed(comp: RationalComponent) -> void:
	if Engine.has_meta(&"Main"):
		Engine.get_meta(&"Main").edit_root(comp) 


func _on_edit_tree_pressed(object: Object, property: String) -> void:
	update_node_path(object, property)
	Engine.get_meta(&"Main").edit_root(object.get(property)) 

func _on_root_changed(root: Resource, object: Object, property: String) -> void:
	if object is Node:
		update_node_path(object, property)
	#object.owner.get_path_to(object)

func _parse_begin(object: Object) -> void:
	is_editing_tree = object is RationalTree
	is_editing_component = object is RationalComponent
	
	if is_editing_component:
		var button: Button = create_button()
		button.pressed.connect(_on_edit_component_button_pressed.bind(object))
		button.pressed.connect(Engine.get_meta(&"Main").edit.bind(object), CONNECT_DEFERRED)


func _parse_category(object: Object, category: String) -> void:
	pass
	#if object is RationalComponent and not ClassDB.class_exists(category):
		#var button: Button = create_button()
		#button.pressed.connect(_on_edit_component_button_pressed.bind(object))


func _on_editor_property_changed(property: StringName, value: Variant, field: StringName, changing: bool, picker: EditorResourcePicker) -> void:
	picker.get_parent().property_can_revert_changed.emit(property, value != null)
	if picker.edited_resource != value:
		picker.edited_resource = value


func _on_picker_changed(res: Resource, editor_property: EditorProperty) -> void:
	editor_property.emit_changed(editor_property.get_edited_property(), res)
	if editor_property.get_edited_object() is Node:
		update_node_path(editor_property.get_edited_object(), editor_property.get_edited_property())


func _on_picker_selected(resource: Resource, inspect: bool, editor_property: EditorProperty) -> void:
	printt(resource, "INSPECTED: %s" % inspect)
	editor_property.select(0)
	if inspect:
		EditorInterface.edit_resource.call_deferred(resource)
	cache.edit_root(resource)



func create_picker(object: Object, property: String, base_type: String = "RationalComponent") -> EditorResourcePicker:
	var picker: EditorResourcePicker = EditorResourcePicker.new()
	picker.base_type = base_type
	picker.theme_type_variation = &"EditorInspectorButton"
	picker.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	picker.edited_resource = object.get(property)
	picker.focus_mode = Control.FOCUS_ALL

	var eprop: EditorProperty = EditorProperty.new()
	eprop.set_object_and_property(object, property)
	eprop.label = property.capitalize()
	eprop.add_child(picker)
	eprop.add_focusable(picker)
	
	eprop.property_changed.connect(_on_editor_property_changed.bind(picker))
	
	picker.resource_changed.connect(_on_picker_changed.bind(eprop))
	picker.resource_selected.connect(_on_picker_selected.bind(eprop))
	
	add_custom_control(eprop)
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
	margins * EditorInterface.get_editor_scale()
	var margin_container := MarginContainer.new()
	margin_container.add_theme_constant_override("margin_left", margins.x)
	margin_container.add_theme_constant_override("margin_right", margins.x)
	margin_container.add_theme_constant_override("margin_top", margins.y)
	margin_container.add_theme_constant_override("margin_bottom", margins.y)
	if child_control: margin_container.add_child(child_control)
	return margin_container
