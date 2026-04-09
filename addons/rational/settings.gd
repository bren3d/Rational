## Handle Rational Plugin ProjectSettings interactions.
@tool
extends RefCounted

const CATEGORY: String = "rational/%s"

const DATA: Dictionary[StringName, Dictionary] = {
	autosave = {
		name = "autosave",
		type = TYPE_BOOL,
		value = true,
		basic = true,
	},
}

static func get_setting(name: String, default: Variant = null) -> Variant:
	return ProjectSettings.get_setting(CATEGORY % name, default if default != null else DATA.get(name, {}).get("value"))

static func set_setting(name: String, value: Variant) -> void:
	return ProjectSettings.set_setting(CATEGORY % name, value)

static func populate() -> void:
	for key: StringName in DATA:
		var setting_path: String = CATEGORY % DATA[key].get("name", "")
		if not ProjectSettings.has_setting(setting_path):
			ProjectSettings.set_setting(setting_path , DATA[key].get("value", 0))
			
		ProjectSettings.add_property_info({
			name = setting_path,
			type = DATA[key].get("type", TYPE_NIL),
			hint = DATA[key].get("hint", PROPERTY_HINT_NONE),
			hint_string = DATA[key].get("hint_string", ""),
			})
		
		ProjectSettings.set_initial_value(setting_path, DATA[key].get("value", 0))
		ProjectSettings.set_as_basic(setting_path, DATA[key].get("basic", true))
