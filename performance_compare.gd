@tool
extends EditorScript

const USECS_TO_SECS: float = 1_000_000.0
const CALL_COUNT: int = 1000

const PATH := "res://TestScene/test_scene_character.tscn::Resource_mg37k"
const NODE_PATH := "Actor/RationalTree:root"
const SCENE_PATH := "res://TestScene/test_scene_character.tscn"

func _run() -> void:
	pass
	

func compare_methods(callables: Array[Callable], call_count: int = CALL_COUNT) -> void:
	print("")
	for callable: Callable in callables:
		average_benchmark(call_count, callable)

func average_benchmark(count: int, callable: Callable) -> void:
	var total_usec: int = 0
	#var start_tick: int = Time.get_ticks_usec()
	for i in count:
		total_usec += get_elapsed_usec(callable)
	#
	#var end_tick: int = Time.get_ticks_usec()
	#var elapsed_ticks: int = end_tick - start_tick
	
	#var total_time: float = float(elapsed_ticks)/ USECS_TO_SECS
	
	var avg_sec: float = float(total_usec)/float(count)/USECS_TO_SECS 
	print("%s \t\t => Calls: %5d | Total sec: %01.05f | Average sec: %01.010f" % [callable, count, float(total_usec)/USECS_TO_SECS, avg_sec])

func get_elapsed_usec(callable: Callable) -> int:
	var start_time:= Time.get_ticks_usec()
	callable.call()
	return Time.get_ticks_usec() - start_time
