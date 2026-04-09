@tool
class_name ReloadPlugin
extends EditorScript

func _run() -> void:
	const PLUGIN_NAME: String = "rational"
	
	if not EditorInterface.is_plugin_enabled(PLUGIN_NAME):
		printerr("Plugin '%s' not enabled" % PLUGIN_NAME)
		return
	
	EditorInterface.set_plugin_enabled(PLUGIN_NAME, false)
	EditorInterface.set_plugin_enabled.call_deferred(PLUGIN_NAME, true)
