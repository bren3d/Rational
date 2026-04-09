@tool
extends EditorPlugin

const Util := preload("util.gd")
const Cache := preload("data/cache.gd")

const Settings := preload("settings.gd")

const WindowWrapper := preload("editor/window_wrapper.gd")
const Editor := preload("editor/main.gd")

const InpsectorPlugin := preload("plugins/inspector/inspector_plugin.gd")
const ActionHandle := preload("editor/action_handle.gd")

var inspector_plugin: InpsectorPlugin

## Cache for all RationalComponent resources. 
var cache: Cache

var action_handle: ActionHandle

var window_wrapper: WindowWrapper
var editor: Editor


func _enter_tree() -> void:
	resource_saved.connect(_on_resource_saved)
	scene_saved.connect(_on_scene_saved)
	get_script_create_dialog().script_created.connect(_on_script_created)
	
	Settings.populate()
	
	name = &"Rational"
	Engine.register_singleton(&"Rational", self)
	
	cache = Cache.new()
	action_handle = ActionHandle.new()
	
	window_wrapper = WindowWrapper.new()
	
	editor = preload("editor/main.tscn").instantiate()
	Engine.set_meta(&"Main", editor)
	editor.propagate_call(&"set_cache", [cache])
	
	EditorInterface.get_editor_main_screen().add_child(window_wrapper)
	
	inspector_plugin = InpsectorPlugin.new()
	add_inspector_plugin(inspector_plugin)
	
	print_rich("[b]Rational™ initialized[/b]")


func _exit_tree() -> void:
	window_wrapper.queue_free()
	
	remove_inspector_plugin(inspector_plugin)
	inspector_plugin = null
	
	#cache.save()
	cache = null
	
	action_handle = null
	
	Engine.set_meta(&"Main", null)
	
	Engine.unregister_singleton(&"Rational")


func _handles(object: Object) -> bool:
	return object is RationalTree and EditorInterface.get_inspector().get_edited_object() != object


func _edit(object: Object) -> void:
	if cache and object and editor:
		editor.edit_tree(object)
	
	if EditorInterface.get_inspector().get_edited_object() != object:
		EditorInterface.inspect_object(object, "", true)

func _make_visible(visible: bool) -> void:
	window_wrapper.make_visible(visible)

func _has_main_screen() -> bool:
	return true

func _get_plugin_icon() -> Texture2D:
	return preload("icon.svg")

func _get_plugin_name() -> String:
	return "Rational"

func _on_scene_saved(filepath: String) -> void:
	print_rich("Scene saved: [color=yellow]%s[/color] " % [filepath])

func _save_external_data() -> void:
	cache.save()

func _get_unsaved_status(for_scene: String) -> String:
	return cache.get_unsaved_status(for_scene) if cache else ""

#region Signal Methods 


func _on_file_moved(old_file: String, new_file: String) -> void:
	cache.update_path(old_file, new_file)

func _on_resource_saved(res: Resource) -> void:
	if res is RationalComponent:
		cache.add_root(res)
		print("Adding root... %s" % res)
		print_rich("Resource saved: %s([color=yellow]%s[/color]) @ [color=pink]%s[/color]" % [res.resource_name, res, res.resource_path])

## Adds '@tool' to RationalComponent Scripts that don't have it already.
func _on_script_created(script: Script) -> void:
	if not script or not script.get_base_script() or not Util.class_is_valid(script.get_base_script().get_global_name()):
		print("Script '%s' doesn't extend RationalComponent" % script)
		return
	
	print("New script is tool: %s" % script.is_tool())
	print("New script contains '@tool': %s" % script.source_code.containsn("@tool"))


#endregion Signal Methods 
