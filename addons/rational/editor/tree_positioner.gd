@tool
extends RefCounted

const LATERAL_SIZE: float = 360.0
const LEVEL_SIZE: float = 240.0

var x: float
var mod: float = 0.0
var level: int = 0

var parent: RefCounted
var children: Array[RefCounted]

var item: GraphNode

func _init(_item: GraphNode = null, _parent: RefCounted = null) -> void:
	parent = _parent
	item = _item

func has_children() -> bool:
	return not children.is_empty()

func is_front() -> bool:
	return not parent or parent.children.front() == self

func get_index() -> int:
	return parent.children.find(self) if parent else 0

func get_previous() -> RefCounted:
	return null if is_front() else parent.children[get_index() - 1]

func get_sibling(idx: int) -> RefCounted:
	return parent.children[idx] if parent else self

func get_cell_size() -> Vector2:
	return Vector2(LEVEL_SIZE, LATERAL_SIZE) if is_horizontal() else Vector2(LATERAL_SIZE, LEVEL_SIZE)

func is_horizontal() -> bool:
	return item.horizontal if item else false

func get_size() -> Vector2:
	return item.size if item else Vector2()

func calculate_tree(depth: int = 0) -> void:
	init_node(depth)
	init_lateral()
	calculate_final_x(0.0)

func init_node(depth: int) -> void:
	x = 0
	mod = 0
	level = depth
	for child: RefCounted in children:
		child.init_node(depth + 1)

func init_lateral() -> void:
	for child: RefCounted in children:
		child.init_lateral()
	
	if is_front():
		x = get_children_center()
	
	else:
		x = get_previous().x + 1.0
		mod = x - get_children_center()
		if has_children():
			check_conflicts()

func get_children_center() -> float:
	return (children[0].x + (children[-1].x - children[0].x) * 0.5) if has_children() else 0.0


func find_left_bound(accum: float = 0.0, dict: Dictionary[int, float] = {}) -> Dictionary:
	dict[level] = minf(dict.get(level, x + accum), x + accum)
	accum += mod
	for child: RefCounted in children:
		child.find_left_bound(accum, dict)
	return dict

func find_right_bound(accum: float = 0.0, dict: Dictionary[int, float] = {}) -> Dictionary:
	dict[level] = maxf(dict.get(level, x + accum), x + accum)
	accum += mod
	for child: RefCounted in children:
		child.find_right_bound(accum, dict)
	return dict

func check_conflicts() -> void:
	var shift: float = 0.0
	var shifted_sibling_index: int = 0
	var left_bound: Dictionary[int, float] = find_left_bound()
	
	for idx: int in get_index():
		var right_bound: Dictionary[int, float]= get_sibling(idx).find_right_bound()
		for sub_level: int in (mini(left_bound.keys().max(), right_bound.keys().max()) + 1 - level):
			var lateral_delta: float = left_bound[level + sub_level] - right_bound[level + sub_level]
			
			if lateral_delta + shift < 1.0:
				shift = 1.0 - lateral_delta
				shifted_sibling_index = idx
	
	if 0 < shift:
		x += shift
		mod += shift
		center_siblings(shifted_sibling_index, get_index())


func center_siblings(from: int, to: int) -> void:
	if to - from < 1: return
	var child_count: int = (to - from - 1)
	var x_delta: float = (get_sibling(to).x - get_sibling(from).x) / float(child_count + 1)
	for i: int in child_count:
		var sibling:= get_sibling(to + i)
		sibling.x += (x_delta * float(i + 1))
		sibling.mod += (x_delta * float(i + 1))

func calculate_final_x(accum: float) -> void:
	x += accum
	accum += mod
	for child: RefCounted in children:
		child.calculate_final_x(accum)

func get_position() -> Vector2:
	var cell_size:= get_cell_size()
	return cell_size * (Vector2(level, x) if is_horizontal() else Vector2(x, level)) + (cell_size - get_size()) / 2.0
