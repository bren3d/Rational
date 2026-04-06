@tool
extends EditorScript

const Util := preload("res://addons/rational/util.gd")

const RATIONAL_SCRIPT_PATH := "res://addons/rational/components/rational_component.gd"
const Cache := preload("res://addons/rational/data/cache.gd")
const Main := preload("res://addons/rational/editor/main.gd")
const TreeDisplay := preload("res://addons/rational/editor/tree_display.gd")
const GraphEditor := preload("res://addons/rational/editor/graph_edit.gd")
const Settings := preload("res://addons/rational/settings.gd")
const ActionHandle := preload("res://addons/rational/editor/action_handle.gd")

enum {
	ITEM_NONE = 0,
	ITEM_ADD_CHILD = 1, 
	ITEM_CUT = 2, 
	ITEM_COPY = 4, 
	ITEM_PASTE = 8, 
	ITEM_DUPLICATE = 16, 
	ITEM_RENAME = 32, 
	ITEM_CHANGE_TYPE = 64, 
	ITEM_SAVE_AS_ROOT = 128, 
	ITEM_DOCUMENTATION = 256, 
	ITEM_DELETE = 512,
	ITEM_ADD_NODE_HERE = 1024,
	ITEM_INSTANTIATE_NODE_HERE = 2048,
	ITEM_INSTANTIATE_NODE = 4096,
	ITEM_PASTE_HERE = 8192,
	
	ITEM_ALL = 4294967295,
}

func _run() -> void:
	print("Running...")
	#const PATH:= "res://TestScene/test_scene_character.tscn::Resource_k2f85"
	var scene:= EditorInterface.get_edited_scene_root()
	#
	if not Engine.has_singleton(&"Rational"): return
	var plugin: EditorPlugin = Engine.get_singleton(&"Rational")
	var cache: Cache = plugin.cache
	var main: Main = plugin.editor
	
	var root_file_tree: TreeDisplay = main.root_file_tree
	var tree_display: TreeDisplay = main.tree_display
	var graph_edit: GraphEditor = main.graph_edit
	
	#var editor_settings: EditorSettings = EditorInterface.get_editor_settings()
	#var data: RootData = cache.get_data_list().front()
	#var comp: RationalComponent = data.root
	#print(comp, comp.get_script().get_base_script().get_global_name())
	#var options:= ITEM_ALL
	#options &= ~(ITEM_PASTE | ITEM_SAVE_AS_ROOT | ITEM_ADD_CHILD)
	#var foo: int = (graph_edit.ITEMS_DEFAULT ^ graph_edit.ITEM_CHANGE_TYPE)
	#printt(foo, bool(foo & graph_edit.ITEM_CHANGE_TYPE))
	#EditorInterface.set_plugin_enabled("Rational", false)
	#print(EditorInterface.set_plugin_enabled("Rational", false))
	#for i in 32:
		#print(1 << i)
	var arr: Array = [0, 1, 2, 3]
	
	#var from_index: int = 3
	#var to_index: int = wrapi(-4, 0, arr.size())
	#
	#var element =  arr.pop_at(from_index)
	#arr.insert(to_index, element)
	
	#printt(bool(options & ITEM_PASTE), bool(options & ITEM_SAVE_AS_ROOT), bool(options & ITEM_ADD_CHILD),)
	
	#print("ACCUM: %d" % accum)
	#print(0b1111111111111111)


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


func foo_print(string: String = "foo_print() called!") -> void:
	printt(string)

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
