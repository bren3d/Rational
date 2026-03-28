@tool
extends EditorPlugin

const Util := preload("util.gd")
const Cache := preload("data/cache.gd")

const Frames := preload("editor/editor_style.gd")
const Editor := preload("editor/main.gd")

const InpsectorPlugin := preload("plugins/inspector/inspector_plugin.gd")

var inspector_plugin: InpsectorPlugin

## Cache for all RationalComponent resources. 
var cache: Cache

var editor: Editor
var frames: Frames

#region Enter/Exit

func _enter_tree() -> void:
	resource_saved.connect(_on_resource_saved)
	scene_saved.connect(_on_scene_saved)
	
	name = &"Rational"
	
	Engine.register_singleton(&"Rational", self)
	
	cache = Cache.new()
	
	editor = preload("editor/main.tscn").instantiate()
	Engine.set_meta(&"Main", editor)
	
	editor.propagate_call(&"set_cache", [cache])
	editor.hide()
	EditorInterface.get_editor_main_screen().add_child(editor)
	
	inspector_plugin = InpsectorPlugin.new()
	inspector_plugin.set_cache(cache)
	add_inspector_plugin(inspector_plugin)
	
	print("Rational initialized")


func _exit_tree() -> void:
	editor.queue_free()
	
	remove_inspector_plugin(inspector_plugin)
	inspector_plugin = null
	
	cache.save()
	cache = null
	
	Engine.remove_meta(&"Frames")
	frames = null

	Engine.remove_meta(&"Main")

	Engine.unregister_singleton(&"Rational")


func _on_file_moved(old_file: String, new_file: String) -> void:
	cache.update_path(old_file, new_file)

func _on_resource_saved(res: Resource) -> void:
	if res is RationalComponent:
		cache.add_root(res)
		print("Adding root... %s" % res)
		print_rich("Resource saved: %s([color=yellow]%s[/color]) @ [color=pink]%s[/color]" % [res.resource_name, res, res.resource_path])


func _handles(object: Object) -> bool:
	return object is RationalTree and EditorInterface.get_inspector().get_edited_object() != object


func _edit(object: Object) -> void:
	if cache and object and editor:
		editor.edit_tree(object)
	
	if EditorInterface.get_inspector().get_edited_object() != object:
		EditorInterface.inspect_object(object, "", true)

func _make_visible(visible: bool) -> void:
	editor.make_visible(visible)

func _has_main_screen() -> bool:
	return true

func _get_plugin_icon() -> Texture2D:
	return preload("icon.svg")

func _get_plugin_name() -> String:
	return "Rational"

func _on_scene_saved(filepath: String) -> void:
	print_rich("Scene saved: [color=yellow]%s[/color] " % [filepath])
