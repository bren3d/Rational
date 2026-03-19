@tool

static func get_plugin() -> EditorPlugin:
	return Engine.get_singleton(&"Rational")

static func comp_get_class(comp: RationalComponent) -> String:
	return comp.get_script().get_global_name() if comp else "ERROR"

static func load_root(path: String) -> RationalComponent:
	if path.containsn("::"):
		var resource_paths: PackedStringArray = path.split("::")
		var scene_path: String = resource_paths[0]
		if not ResourceLoader.exists(scene_path, "PackedScene"):
			printerr("Broken load path for RationalComponent: %s" % path)
			return null
		var state: SceneState = ResourceLoader.load(scene_path, "PackedScene").get_state()
		for i: int in state.get_node_count():
			for j: int in state.get_node_property_count(i):
				if state.get_node_property_value(i, j) is RationalComponent:
					var root: RationalComponent = state.get_node_property_value(i, j)
					if root.resource_path == path:
						return root.duplicate(true)
	
	else: 
		return ResourceLoader.load(path)
	
	return null


## Sets [param root.resource_name] if different.
static func generate_unique_name(root: RootData, name_list: PackedStringArray) -> String:
	if not root: 
		return ""
	
	if not root.resource_name:
		root.resource_name = root.get_script().get_global_name()
	
	if not root.resource_name in name_list:
		return root.resource_name
	
	var base_name: String = root.resource_name
	var result: String = root.resource_name

	var i: int = 0
	while (i + 1) < result.length() and result.right(i + 1).is_valid_int():
		i += 1
		
	if i > 0:
		base_name = result.left(result.length() - i)
		i = result.right(i).to_int()
	
	while result in name_list:
		result = base_name + str(i)
		i += 1
	
	if root.resource_name != result:
		root.resource_name = result
	
	return result
