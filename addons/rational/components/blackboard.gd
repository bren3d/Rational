@tool
@icon("../icons/Blackboard.svg")
class_name Blackboard extends Resource

const DEFAULT: String = "default"
const SHARED: String = "shared"

## Use [method set_value], and [method get_value] to access.
@export var board_data: Dictionary = {}: set = set_board_data

## [Blackboard] for use between multiple blackboards.
@export var global_data: Blackboard: set = set_global_data

var _data: Dictionary


func get_value(key: String, default: Variant = null, section: String = DEFAULT) -> Variant:
	return _data.get(section, {}).get(key, default)

func set_value(key: String, value: Variant, section: String = DEFAULT) -> void:
	_data.get_or_add(section, {})[key] = value


func has(key: String, section: String = DEFAULT) -> bool:
	return _data.get(section, {}).has(key)


func erase(key: String, section: String = DEFAULT) -> bool:
	if has(key, section):
		return _data.get(section, {}).erase(key)
	return false


func get_global(key: String, default: Variant = null) -> Variant:
	return get_value(key, default, SHARED)

func set_global(key: String, value: Variant = null) -> void:
	set_value(key, value, SHARED)


func get_local(key: String, default: Variant = null) -> Variant:
	return get_value(key, default)

func set_local(key: String, value: Variant = null) -> void:
	set_value(key, value)


func set_board_data(val: Dictionary) -> void:
	board_data = val
	_data[DEFAULT] = board_data

func set_global_data(val: Blackboard) -> void:
	global_data = val
	_data[SHARED] = global_data.board_data if board_data else {}
