@tool
extends EditorScript

const RES_PATH:= "res://TestScene/RationalObjects/deco.tres"
const RATIONAL_SCRIPT_PATH:= "res://addons/rational/components/rational_component.gd"
const Cache := preload("res://addons/rational/data/cache.gd")
const Main:= preload("res://addons/rational/editor/main.gd")
const TreeDisplay:= preload("res://addons/rational/editor/tree_display.gd")

const Util:= preload("res://addons/rational/util.gd")

#var data: Dictionary = {key = "key"}

var tw: Tween
@export var path_list: PackedStringArray
#const Util := preload("res://addons/rational/util.gd")
#const RationalPicker = preload("res://addons/rational/plugins/inspector/rational_property.gd")

func _run() -> void:
	print("Running...")
	const PATH:= "res://TestScene/test_scene_character.tscn::Resource_k2f85"
	var scene:= EditorInterface.get_edited_scene_root()
	#scene.theme = EditorInterface.get_editor_theme()
	#return
	
	var plugin: EditorPlugin = Engine.get_singleton(&"Rational")
	var cache: Cache = plugin.cache
	
	var main: Main = Engine.get_meta(&"Main")
	var tree_display: TreeDisplay = main.tree_display
	
	EditorInterface.get_inspector().print_tree_pretty()
	#for data: RootData in cache.get_data_list():
		#printt(data, "| ID: %s" % ResourceLoader.get_resource_uid(data.path))
		


func _on_texture_changed(tex: Texture2D) -> void:
	print("texture changed: %s" % tex)


func shortcut_get_accel(shortcut_path: String) -> Key:
	var shortcut: Shortcut = EditorInterface.get_editor_settings().get_shortcut(shortcut_path)
	if shortcut:
		for event in shortcut.events:
			if event is InputEventKey:
				return event.get_keycode_with_modifiers()
	else:
		print("No shortcut found!")
	return KEY_NONE

func print_cache(c: Cache) -> void:
	printt("Paths: ", " | ".join(c.path_list))
	var root_names: PackedStringArray
	#for root in c.root_list:
		#root_names.push_back(root.resource_name)
	printt("Roots: ", " | ".join(root_names))



func populate_class_icons() -> Dictionary[StringName, Texture2D]:
	var class_list: Array[Dictionary] = ProjectSettings.get_global_class_list()
	var class_icons: Dictionary[StringName, Texture2D]
	
	for dict: Dictionary in class_list:
		if dict.class != &"RationalComponent": continue
		class_icons[&"RationalComponent"] = load(dict.icon)
	
	var base_classes: Array[StringName] = [&"RationalComponent"]
	while not base_classes.is_empty():
		var new_bases: Array[StringName] = []
		for dict: Dictionary in class_list:
			if dict.base in base_classes:
				new_bases.push_back(dict.class)
				class_icons[dict.class] = load(dict.icon) if dict.icon else class_icons[dict.base]
		base_classes = new_bases
	
	return class_icons

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
