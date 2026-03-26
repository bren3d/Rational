@tool
extends ResourceFormatLoader

var blocked_paths: PackedStringArray

func _handles_type(type: StringName) -> bool:
	return type == &"Resource"

func _load(path: String, original_path: String, use_sub_threads: bool, cache_mode: int) -> Variant:
	
	if ResourceLoader.exists(path, "RationalComponent"):
		return null
	#if not blocked_paths.push_back()
	if ResourceLoader.exists(original_path):
		return ResourceLoader.load(original_path)
		
	return ResourceLoader.load(path, "", cache_mode)


func _exists(path: String) -> bool:
	return false
