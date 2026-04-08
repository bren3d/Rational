@tool
extends ResourceFormatLoader

const Util := preload("../../util.gd")
const ClassData := preload("../../data/rational_class_data.gd")

var class_data: ClassData
var script_list: PackedStringArray
#var blocked_paths: PackedStringArray

func _init() -> void:
	class_data = Util.get_class_data()
	#class_data.class_data_updated.connect()
	#populate_script_list()

func _handles_type(type: StringName) -> bool:
	return type == &"Resource"

func _recognize_path(path: String, type: StringName) -> bool:
	#if not path.get_extension() in 
	return false

func _load(path: String, original_path: String, use_sub_threads: bool, cache_mode: int) -> Variant:
	if ResourceLoader.exists(path, "RationalComponent"):
		return null
	
	if ResourceLoader.exists(original_path):
		return ResourceLoader.load(original_path)
		
	return ResourceLoader.load(path, "", cache_mode)

func _get_recognized_extensions() -> PackedStringArray:
	const EXTENSIONS: PackedStringArray = [".tres", ".res"]
	return EXTENSIONS

func _exists(path: String) -> bool:
	return false


func update_script_list() -> void:
	script_list = class_get_script_list(&"RationalComponent")


func class_get_script_list(_class: StringName) -> PackedStringArray:
	var result: PackedStringArray
	var inheretors: Array[StringName]
	for dict: Dictionary in ProjectSettings.get_global_class_list():
		if dict.class == _class:
			result.push_back(dict.script)
		elif dict.base == _class:
			inheretors.push_back(dict.class)
	
	for subclass: StringName in inheretors:
		result.append_array(class_get_script_list(subclass))
	
	return result
