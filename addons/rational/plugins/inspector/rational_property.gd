@tool
extends EditorProperty

#const Util := preload("res://addons/rational/util.gd")
var picker: EditorResourcePicker


func _init(object: Object, property: String, base_type: String = "RationalComponent") -> void:
	EditorResourcePicker.new()
	picker.base_type = base_type
	picker.theme_type_variation = &"EditorInspectorButton"
	picker.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label = property
	set_object_and_property(object, property)

func _update_property() -> void:
	get_edited_object().set(get_edited_property(), picker.edited_resource)
