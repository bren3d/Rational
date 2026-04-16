@tool
extends VBoxContainer

const SIGNAL_UPDATE: StringName = &"update_display"

signal property_changed(property: StringName, value: Variant, field: StringName, changing: bool)

var action_handle: RefCounted = Engine.get_singleton(&"Rational").action_handle

var block_update: bool = false

func update_display(comp: Object) -> void:
	clear()
	
	for con: Dictionary in get_incoming_connections():
		if con.callable != update_properties: continue
		con.signal.disconnect(con.callable)
	
	if not comp: 
		return
	
	
	if not comp.has_user_signal(SIGNAL_UPDATE):
		comp.add_user_signal(SIGNAL_UPDATE, [{name = "args", type = TYPE_ARRAY}])
	
	comp.connect(SIGNAL_UPDATE, update_properties, CONNECT_APPEND_SOURCE_OBJECT)
	
	for prop: Dictionary in get_component_properties(comp):
		var ep: EditorProperty = EditorInspector.instantiate_property_editor(comp, prop.type, prop.name, prop.hint, prop.hint_string, prop.usage)
		ep.mouse_filter = Control.MOUSE_FILTER_STOP
		ep.draw_background = false
		ep.selectable = false
		ep.use_folding = true
		ep.set_object_and_property(comp, prop.name)
		ep.label = prop.name
		ep.update_property()
		ep.property_changed.connect(_on_property_edited, CONNECT_APPEND_SOURCE_OBJECT)
		add_child(ep)

func _on_property_edited(property: StringName, value: Variant, field: StringName, changing: bool, ep: EditorProperty) -> void:
	if block_update or not changing or not property or not ep: return
	var obj: Object = ep.get_edited_object()
	assert(obj, "No object set for EditorProperty.")
	action_handle.create_action("Set %s" % property, UndoRedo.MERGE_ENDS)
	action_handle.undo_redo.add_undo_method(obj, &"emit_signal", SIGNAL_UPDATE, [property, obj.get(property)])
	action_handle.undo_redo.add_do_method(obj, &"emit_signal", SIGNAL_UPDATE, [property, value])
	action_handle.commit(false)

func update_properties(args: Array = [], obj: Object = null) -> void:
	if not args: return
	block_update = true
	obj.set(args[0], args[1])
	for ep: EditorProperty in get_editor_properties():
		if ep.get_edited_property() == args[0]:
			ep.update_property()
	block_update = false
	

func get_editor_properties() -> Array[EditorProperty]:
	var result: Array[EditorProperty]
	for child in get_children():
		if not child is EditorProperty: continue
		result.push_back(child)
	return result

func clear() -> void:
	for editor_property: EditorProperty in get_editor_properties():
		remove_child(editor_property)
		editor_property.free()

func get_component_properties(comp: Object) -> Array[Dictionary]:
	var result: Array[Dictionary]
	const IGNORED_PROPERTY_NAMES: PackedStringArray = ["children", "child", "resource_local_to_scene", "resource_path", "resource_name", "script"]
	for property: Dictionary in comp.get_property_list():
		if not property.usage & PROPERTY_USAGE_EDITOR: continue
		if property.name.contains("metadata/"): continue
		if property.name in IGNORED_PROPERTY_NAMES: continue
		result.push_back(property)
	return result

func has_properties() -> bool:
	return 0 < get_child_count()
