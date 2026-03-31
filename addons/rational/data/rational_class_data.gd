@tool
extends RefCounted

signal class_data_updated

var class_data: Dictionary[StringName, Dictionary]

func _init() -> void:
	Engine.set_meta(&"RationalClassData", self)
	update_class_data()
	EditorInterface.get_resource_filesystem().script_classes_updated.connect(update_class_data)

func add_class_data(_class: StringName) -> void:
	var inheretors: Array[StringName]
	for dict: Dictionary in ProjectSettings.get_global_class_list():
		if dict.class == _class:
			class_data[_class] = dict.duplicate()
			class_data[_class].icon = ResourceLoader.load(dict.icon, "Texture2D") if dict.icon else class_get_icon(dict.base)
			class_data[_class].script = ResourceLoader.load(dict.path, "GDScript")
		
		elif dict.base == _class:
			inheretors.push_back(dict.class)
	
	for subclass: StringName in inheretors:
		add_class_data(subclass)

func update_class_data() -> void:
	class_data.clear()
	add_class_data(&"RationalComponent")
	class_data_updated.emit()

func instantiate_class(_class: StringName) -> Object:
	var script: Script = class_get_script(_class)
	var class_object: Object
	if not script:
		printerr("Cannot instantiate class '%s': No script found." % _class)
	elif script.is_abstract():
		printerr("Cannot instantiate class '%s': Class is abstract." % _class)
	else:
		class_object = script.new()
		class_object.set(&"resource_name", _class)
	return class_object

func class_get_data(_class: StringName) -> Dictionary:
	return class_data.get(_class, {
		"base" : &"INVALID",
		"class": &"INVALID",
		"icon": null,
		"script": null,
		"language": &"GDScript",
		"path": "INVALID",
		"is_abstract": false,
		"is_tool": false,
	})

func class_get_base(_class: StringName) -> StringName:
	return class_get_data(_class).get("base", &"RationalComponent")

func class_get_icon(_class: StringName) -> Texture2D:
	return class_get_data(_class).get("icon", get_default_class_icon())

func class_get_script(_class: StringName) -> GDScript:
	return class_get_data(_class).get("script")

func class_is_abstract(_class: StringName) -> bool:
	return class_get_data(_class).get("is_abstract", false)

func class_is_tool(_class: StringName) -> bool:
	return class_get_data(_class).get("is_tool", false)

func class_has_icon(_class: StringName) -> bool:
	return class_get_icon(_class) != null
	
func class_has_script(_class: StringName) -> bool:
	return class_get_script(_class) != null

func class_extends_rational_component(_class: StringName) -> bool:
	return _class in class_data

func class_extends_class(_class: StringName, base_class: StringName) -> bool:
	return _class in class_get_inhereters(base_class, true)

func class_is_valid(_class: StringName) -> bool:
	return class_extends_rational_component(_class) and class_has_script(_class)

func script_path_is_valid(path: String) -> bool:
	return ResourceLoader.exists(path, "GDScript") and class_extends_rational_component(load(path).get_global_name())

func comp_get_script(comp: Object) -> Script:
	return comp.get_script() if comp else null

func comp_get_class(comp: Object) -> String:
	return comp.get_script().get_global_name() if comp else ""

func comp_get_icon(comp: Object) -> Texture2D:
	return class_get_icon(comp_get_class(comp))

func get_default_class_icon() -> Texture2D:
	return class_get_data(&"RationalComponent").get("icon")

func class_get_inhereters(_class: StringName, recursive: bool = false) -> Array[StringName]:
	var result: Array[StringName]
	for dict: Dictionary in class_data.values():
		if dict.base != _class: continue
		result.push_back(dict.class)
		if recursive:
			result.append_array(class_get_inhereters(dict.class, recursive))
	return result
