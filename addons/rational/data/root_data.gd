@tool
class_name RootData extends RefCounted

const TIMEOUT_MSEC: int = 5000

## Emitted when data changed.
signal changed

signal tree_changed

signal request_edit

signal closed

signal unsaved_changes_changed

signal data_saved

signal loaded

var root: RationalComponent: set = set_root, get = get_root

var path: String: set = set_path, get = get_path

var name: String: set = set_name

var unsaved_changes: bool = false: set = set_unsaved_changes, get = has_unsaved_changes

func _init(_path: String = "", _root: RationalComponent = null) -> void:
	# Must set path before root. 
	set_meta(&"_loading", true)
	path = _path if _path or not _root else _root.resource_path
	root = _root
	
	Engine.get_main_loop().process_frame.connect(load_path, CONNECT_ONE_SHOT | CONNECT_DEFERRED)


func is_root(_root: RationalComponent) -> bool:
	return _root and ((path and _root.resource_path == path) or root == _root) 


func is_path(_path: String) -> bool:
	return path and path == _path 


func is_root_or_path(_root: RationalComponent, _path: String) -> bool:
	return is_root(_root) or is_path(_path)


func can_save() -> bool:
	return path != ""


func get_root_class() -> String:
	return root.get_script().get_global_name() if root else ""


func rename(to_name: String) -> void:
	if to_name == name: return
	name = to_name
	set_unsaved_changes(true)

func get_root() -> RationalComponent:
	return root

func set_root(val: RationalComponent) -> void:
		if root == val: return
		
		for con: Dictionary in get_incoming_connections():
			var obj: Object = con.signal.get_object()
			if obj is RationalComponent:
				con.signal.disconnect(con.callable)
		
		root = val
		set_block_signals(true)
		
		if val:
			root = val
			root.changed.connect(_on_root_changed)
			root.script_changed.connect(_on_root_script_changed)
			root.tree_changed.connect(_on_tree_changed)
			name = root.resource_name
		
		set_block_signals(false)
		changed.emit()

func get_path() -> String:
	return path

func set_path(val: String) -> void:
	if path == val: return
	path = val
	#if not get_meta(&"_loading", false):
		#if root and root.resource_path != path:
			#root.take_over_path(path)
	changed.emit()

func clear_path() -> void:
	print("Clearing path for %s" % self)
	if root:
		root.resource_path = ""
	else:
		set_path("")

func set_name(val: String) -> void:
		if name == val: return
		name = val if val else get_root_class()
		if root and root.resource_name != name:
			root.resource_name = name
		changed.emit()

func has_unsaved_changes() -> bool:
	return unsaved_changes


# NOTE: Child components are not updated immediately in inspector.
func set_unsaved_changes(val: bool) -> void:
	if unsaved_changes == val: return
	unsaved_changes = val
	EditorInterface.set_object_edited(root, not val)
	if unsaved_changes:
		mark_scene_unsaved()
	unsaved_changes_changed.emit()

func save_as(save_path: String) -> Error:
	if not save_path:
		return ERR_FILE_BAD_PATH
	
	if save_path == path:
		return save()
	
	var root_copy: RationalComponent = duplicate_root()
	root_copy.take_over_path(save_path)
	return ResourceSaver.save(root_copy, save_path, )


func save() -> Error:
	if not root:
		return ERR_INVALID_DATA
	
	var err: int = ERR_BUG
	
	if is_temp():
		err = ERR_UNCONFIGURED
	
	elif is_builtin():
		if not is_scene_open():
			printerr("Built-in Resource %s is open while scene is closed." % self)
		elif not ResourceLoader.exists(path, "Resource"):
			err = ERR_FILE_BAD_PATH
		elif ResourceLoader.load(path, "Resource") != root:
			err = ERR_ALREADY_EXISTS
		else:
			err = OK
			
	
	elif not is_save_path_valid(path):
		err = ERR_FILE_BAD_PATH
	
	else:
		if root.resource_path != path:
			root.take_over_path(path)
		err = ResourceSaver.save(root, path)
	
	match err:
		OK:
			set_unsaved_changes(false)
			data_saved.emit()
			print("Saved: %s" % self)
		ERR_BUG:
			printerr("BUGGED => RootData did not return true for any of is_temp, is_external, is_builtin.")
		ERR_ALREADY_EXISTS:
			printerr("Error saving %s => %s. \nDESYNC: Resource loaded from path is different from RootData." %[self, error_string(err)])
		ERR_UNCONFIGURED, ERR_FILE_BAD_PATH, _:
			printerr("Error saving %s => %s" %[self, error_string(err)])
	
	return err


## Returns [code]true[/code] if [param save_path] is valid to save to.
func is_save_path_valid(save_path: String) -> bool:
	return path.get_file().is_valid_filename() and DirAccess.dir_exists_absolute(path.get_base_dir())

## Clears/Modifies path/root if needed. Call after filesystem is loaded.
func validate_path() -> void:
	if is_temp() or ResourceLoader.exists(path, "Resource"):
		return
	
	if is_builtin():
		if is_scene_subresource():
			return
		printerr("RootData '%s' not found in scene '%s'" % [name, get_scene_file()])
	
	elif root and is_save_path_valid(path):
		root.take_over_path(path)
		ResourceSaver.save(root, path)
		return
	
	printerr("Invalid RootData path: %s. Clearing..." % path)
	clear_path()


func serialize() -> Dictionary:
	return {
		path = path,
		root = root.duplicate_deep(Resource.DEEP_DUPLICATE_INTERNAL),
		}

static func deserialize(data: Dictionary) -> RootData:
	var data_path: String = data.get("path", "") if data.get("path", "") is String else ""
	var data_root: RationalComponent = data.get("root", null) if data.get("root", null) is RationalComponent else null
	return RootData.new(data_path, data_root)

func load_path() -> void:
	validate_path()
	
	if not get_path() or (root and get_path() == root.resource_path):
		set_meta(&"_loading", null)
		loaded.emit()
		return
	
	var err:= await load_deferred()
	
	match err:
		OK:
			print_rich("[color=green]Loaded %s successfully.[/color]" % self)
		
		ERR_FILE_UNRECOGNIZED:
			printerr("Resource at path '%s' does not extend RationalComponent. Caching %s without path." % [path, self])
			clear_path()
		
		ERR_TIMEOUT:
			if is_builtin() and not is_scene_open():
				push_warning("Timeout trying to load '%s'. Closing..." % self)
				closed.emit()
			else:
				push_warning("Timeout trying to load '%s'. Closing..." % self)
				clear_path()
		_:
			printerr("Unknown error loading path '%s' => %s" % [path, error_string(err)])
			clear_path()
	
	set_meta(&"_loading", null)
	loaded.emit()


func load_deferred() -> Error:
	
	# Use Cached Ref for built-ins to avoid ResourceLoader throwing errors 'Resource file not found' and 'Error loading resource' .
	var check_callable: Callable = ResourceLoader.has_cached if is_builtin() else ResourceLoader.exists
	var load_callable: Callable = ResourceLoader.get_cached_ref if is_builtin() else ResourceLoader.load.bind("", ResourceLoader.CACHE_MODE_REPLACE)
	
	var start_tick: int = Time.get_ticks_msec()
	while Time.get_ticks_msec() - start_tick < TIMEOUT_MSEC:
		if check_callable.call(path):
			var res: Resource = load_callable.call(path)
			if not res is RationalComponent:
				printerr("Resource at path '%s' is not type 'RationalComponent'." % path)
				return ERR_FILE_UNRECOGNIZED
			
			set_root(res)
			return OK
		
		await Engine.get_main_loop().process_frame
	
	return ERR_TIMEOUT



func mark_scene_unsaved() -> void:
	if not is_builtin(): return
	var scene_file:= get_scene_file()
	assert(is_scene_open(), "Built-in %s active while scene is not." % self)
	
	var current_scene: String = EditorInterface.get_edited_scene_root().scene_file_path
	
	EditorInterface.open_scene_from_path(scene_file)
	EditorInterface.mark_scene_as_unsaved()
	EditorInterface.open_scene_from_path.call_deferred(current_scene)

func edit() -> void:
	request_edit.emit()

func _on_root_changed() -> void:
	name = root.resource_name
	path = root.resource_path

func _on_root_script_changed() -> void:
	set_unsaved_changes(true)
	changed.emit()

func _on_tree_changed() -> void:
	set_unsaved_changes(true)
	tree_changed.emit()

func is_loaded() -> bool:
	return not get_meta(&"_loading", false)

## Returns [code]true[/code] if root is saved to file.
func is_external() -> bool:
	return FileAccess.file_exists(get_path())

## Returns [code]true[/code] if root is subresource of a PackedScene.
func is_builtin() -> bool:
	return get_path().contains("::")

## Returns [code]true[/code] if root has no path and is only saved in cache.
func is_temp() -> bool:
	return not get_path()

## Returns file of scene if root is built-in else returns [code]""[/code]
func get_scene_file() -> String:
	return get_path().get_slice("::", 0) if is_builtin() else ""

## Returns Resource ID in scene if root is built-in else returns [code]""[/code]
func get_scene_id() -> String:
	return get_path().get_slice("::", 1) if is_builtin() else ""

func is_scene_open() -> bool:
	assert(is_builtin(), "Cannot check scene for non-built-in Resource %s" % self)
	return get_scene_file() in EditorInterface.get_open_scenes()

## Returns [code]true[/code] if Resource ID is found in scene file text.
func is_scene_subresource() -> bool:
	if not is_builtin():
		return false
	var scene_file:= get_scene_file()
	if not FileAccess.file_exists(scene_file):
		return false
	return FileAccess.get_file_as_string(scene_file).contains(get_scene_id())

func duplicate_root(deep_subresources_mode: Resource.DeepDuplicateMode = Resource.DEEP_DUPLICATE_INTERNAL) -> RationalComponent:
	return root.duplicate_deep(deep_subresources_mode) if root else null

func _to_string() -> String:
	return "RootData: %s | Path %s" % [root, path]
