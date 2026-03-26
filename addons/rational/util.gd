@tool

static func get_plugin() -> EditorPlugin:
	return Engine.get_singleton(&"Rational")

static func get_frames() -> RefCounted:
	return get_plugin().frames

static func comp_get_class(comp: RationalComponent) -> String:
	return comp.get_script().get_global_name() if comp else "ERROR"

static func comp_get_icon(comp: RationalComponent) -> Texture2D:
	return get_plugin().cache.class_get_icon(comp_get_class(comp))
