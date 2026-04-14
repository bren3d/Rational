@tool
extends EditorScript

class TestIter:
	const ARRAY:= ["ZERO", "ONE", "TWO"]
	func _iter_init(iter: Array) -> bool:
		iter[0] = [0, ARRAY]
		return iter[0][0] < iter[0][1].size()

	func _iter_next(iter: Array) -> bool:
		iter[0][0] = iter[0][0] + 1
		return iter[0][0] < iter[0][1].size()

	func _iter_get(iter: Variant) -> Variant:
		return iter[1][iter[0]] 


const SCENE_PATH:= "res://TestScene/test_scene_character.tscn"

const RATIONAL_SCRIPT_PATH := "res://addons/rational/components/rational_component.gd"

const Util := preload("res://addons/rational/util.gd")

const RationalPlugin := preload("res://addons/rational/plugin.gd")
const InpsectorPlugin := preload("res://addons/rational/plugins/inspector/inspector_plugin.gd")
const Cache := preload("res://addons/rational/data/cache.gd")
const ClassData := preload("res://addons/rational/data/rational_class_data.gd")
const Selection := preload("res://addons/rational/editor/selection.gd")

const Main := preload("res://addons/rational/editor/main.gd")
const RootFileList := preload("res://addons/rational/editor/root_file_list.gd")
const TreeDisplay := preload("res://addons/rational/editor/tree_display.gd")
const GraphEditor := preload("res://addons/rational/editor/graph_edit.gd")
const Settings := preload("res://addons/rational/settings.gd")
const ActionHandle := preload("res://addons/rational/editor/action_handle.gd")

func _run() -> void:
	print("Running...")
	if not Engine.has_singleton(&"Rational"): return
	var plugin: RationalPlugin = Engine.get_singleton(&"Rational")
	var inspector := EditorInterface.get_inspector()
	var undo_redo: EditorUndoRedoManager = EditorInterface.get_editor_undo_redo()
	var ur: UndoRedo = undo_redo.get_history_undo_redo(undo_redo.GLOBAL_HISTORY)
	var scene := EditorInterface.get_edited_scene_root()
	
	var inspector_plugin: InpsectorPlugin = plugin.inspector_plugin
	var cache: Cache = plugin.cache
	var class_data: ClassData = plugin.class_data
	var selection: Selection = plugin.selection
	var action_handle: ActionHandle = plugin.action_handle
	
	var main: Main = plugin.editor
	var root_file_tree: RootFileList = main.root_file_tree
	var tree_display: TreeDisplay = main.tree_display
	var graph_edit: GraphEditor = main.graph_edit
	
	const PATH := "res://TestScene/test_scene_character.tscn::Resource_4t32f"
	const PATH2 := "res://TestScene/test_scene_character.tscn::Resource_q1v5c"
	#const LEVEL_COUNTS: PackedInt32Array = [3, ]
	
	var root: TestNode = TestNode.new()
	
	var child_1: TestNode = TestNode.new()
	for i in 3:
		child_1.children.push_back(TestNode.new())
		
	var child_2: TestNode = TestNode.new()
	for i in 2:
		child_2.children.push_back(TestNode.new())
	
	root.children.push_back(child_1)
	root.children.push_back(child_2)
	
	root.calculate_lateral()
	root.print_tree_coords()
	
	


class TestNode extends RefCounted:
	var index: int = 0
	var size: int = 1
	var level: int = 0
	
	var parent: TestNode
	var children: Array[TestNode]
	
	func is_leftmost() -> bool:
		return not parent or parent.children.front() == self
	
	func is_rightmost() -> bool:
		return not parent or parent.children.back() == self
	
	func calculate_lateral(idx: int = 0, depth: int = 0) -> void:
		index = idx
		level = depth
		var delta: int = 0
		for i: int in children.size():
			children[i].parent = self
			children[i].calculate_lateral(idx + delta, depth + 1)
			delta += children[i].size
		size = maxi(delta, 1)
	
	func get_cell() -> float:
		return float(index) + float(size)/2.0
		
	func print_tree_coords() -> void:
		#var cell:= get_cell()
		
		print("Cell: %01.01f, %d" % [get_cell(), level])
		for child in children:
			child.print_tree_coords()
	#
	#func get_print_string() -> String:
		
	

func print_selection() -> void:
	var data: Dictionary = Engine.get_singleton(&"Rational").selection._data
	for key in data:
		print("- -%s- -" % key)
		for comp in data[key].selection:
			print("\t%s" % comp)
	


func get_all_components() -> Array[RationalComponent]:
	var result: Array[RationalComponent]
	
	var fs: EditorFileSystemDirectory = EditorInterface.get_resource_filesystem().get_filesystem()
	#for
	return result

func get_component_paths_in_dir(dir: EditorFileSystemDirectory = EditorInterface.get_resource_filesystem().get_filesystem()) -> PackedStringArray:
	var result: PackedStringArray
	var dependency_string: String = "%s::::%s" % [ResourceUID.path_to_uid(RATIONAL_SCRIPT_PATH), RATIONAL_SCRIPT_PATH]
	for i: int in dir.get_file_count():
		if dir.get_file_type(i) == &"Resource":
			var file_path: String = dir.get_path().path_join(dir.get_file(i))
			#var dependencies:= ResourceLoader.get_dependencies(file_path)
			#if dependency_string in dependencies:
			#if load()
				#result.push_back(file_path)
			#else:
			
				
	
	for j: int in dir.get_subdir_count():
		result.append_array(get_component_paths_in_dir(dir.get_subdir(j)))
	return result

func get_property(name: StringName) -> Dictionary:
	for dict in get_property_list():
		if dict.name == name:
			return dict
	return {}

func print_cache(c: Cache) -> void:
	printt("Paths:\n —", "\n —".join(c.path_list))


func write_file(text: String, path: String = "res://temp.txt") -> void:
	var fa: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	fa.store_string(text)
	fa.close()


func get_class_files(type_name: StringName = &"", dir: EditorFileSystemDirectory = EditorInterface.get_resource_filesystem().get_filesystem()) -> PackedStringArray:
	var files: PackedStringArray
	for i: int in dir.get_file_count():
		#if not type_name or dir.get_file_type(i) == type_name: 
			print("(%s) Script is of type: " % dir.get_file(i), dir.get_file_script_class_name(i))
			files.push_back(dir.get_file(i))
	for i: int in dir.get_subdir_count():
		files.append_array(get_class_files(type_name, dir.get_subdir(i)))
	return files


func print_inspector_path() -> void:
	var inspector := EditorInterface.get_inspector()
	print_rich("[color=pink]%s[/color]:%s" % [inspector.get_edited_object(), inspector.get_selected_path()])

func find_resource_type(resource_type: StringName) -> PackedStringArray:
	var fs: EditorFileSystem = EditorInterface.get_resource_filesystem()
	
	while fs.is_scanning():
		print("Waiting for scan...")
		await Engine.get_main_loop().process_frame
		
	return search_dir(resource_type, fs.get_filesystem())


func search_dir(type: StringName, dir: EditorFileSystemDirectory) -> PackedStringArray:
	var result: PackedStringArray = PackedStringArray()
	for i: int in dir.get_file_count():
		#result.append("%s: %s"%[dir.get_file(i), dir.get_file_type(i)])
		
		match dir.get_file_type(i):
			
			type:
				result.append("%s: %s" % [dir.get_file(i), dir.get_file_type(i)])
				
			&"PackedScene":
				result += get_packed_resources(type, load(dir.get_file_path(i)))
				
		result.append(dir.get_file_path(i))

	for i: int in dir.get_subdir_count():
		result += search_dir(type, dir.get_subdir(i))
		
	return result

func get_packed_resources(type: StringName, packed: PackedScene) -> PackedStringArray:
	var result: PackedStringArray = PackedStringArray()
	for element: Variant in packed.bundled.get("variants", []):
		
		if is_instance_of(element, RationalComponent):
			result.append("%s: %s" % [element.get_class(), element.resource_path])
	return result


func _on_gui_focus_changed(focus: Control) -> void:
	print_rich("Focus:\t[color=pink]%s[/color]\t@(%1.0f,%1.0f)" % [focus, focus.global_position.x, focus.global_position.y])
	

func print_node_tree(node: Node, level: int = 0) -> void:
	const INDENT: String = "⎯⎯"
	print(INDENT.repeat(level), node.name)
	for child in node.get_children(true):
		if child is Window: continue
		print_node_tree(child, level + 1)

## Surrounds [code]txt[/code] in bbc color code with color [code]color[/code]
func col(txt: String, color: String = "pink") -> String:
	return "[color=%s]%s[/color]" % [color, txt]

func ts(use_bbcode: bool = true) -> String:
	if use_bbcode: return "[color=pink]%1.3f[/color] secs" % (Time.get_ticks_msec() / 1000.0)
	return "%1.3f secs" % (Time.get_ticks_msec() / 1000.0)
