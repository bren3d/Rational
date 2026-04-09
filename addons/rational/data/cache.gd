@tool
extends RefCounted
## Manages [RationalComponent] roots and stores editor data.

const FILENAME: String = "cache.cfg"

const SECTION: String = "root_data_list"
const KEY_ROOT_DATA: String = "roots"

signal data_added(data: RootData)
signal data_erased(data: RootData)

signal data_saved(data: RootData)
signal data_closed(data: RootData)

## Emited when [param root] needs to be saved via file dialog.
signal request_save_as(data: RationalComponent)

## Emitted when the selected RationalComponent tree root changes.
signal edited_tree_changed(data: RootData)

## Class icon textures.
var class_icons: Dictionary[StringName, Texture2D]

var root_data_list: Array[RootData]

var edited_tree: RootData: set = set_edited_tree, get = get_edited_tree

func get_edited_tree() -> RootData:
	return edited_tree

func set_edited_tree(val: RootData) -> void:
	if edited_tree == val: return
	
	if not val in root_data_list:
		add_data(val)
	
	edited_tree = val
	
	edited_tree_changed.emit(val)
	
	if edited_tree:
		edited_tree.request_edit.emit()


func edit_tree(tree_data: RootData) -> void:
	if not tree_data: return
	set_edited_tree(tree_data)
	EditorInterface.set_main_screen_editor("Rational")

func edit_root(root: RationalComponent) -> void:
	if not has_root(root):
		add_root(root, "")
	
	edit_tree(root_get_data(root))

func edit_rational_tree(tree: RationalTree) -> void:
	if not tree: return
	edit_root(tree.root)

func _init() -> void:
	EditorInterface.get_file_system_dock().files_moved.connect(_on_file_moved)
	EditorInterface.get_file_system_dock().resource_removed.connect(_on_resource_removed)
	Engine.get_singleton(&"Rational").scene_closed.connect(_on_scene_closed, CONNECT_DEFERRED)

func _on_scene_closed(filepath: String) -> void:
	for rd: RootData in get_data_list():
		if not rd.get_path().containsn(filepath): continue
		erase_data(rd)

#region Paths/Roots

func get_data(root: RationalComponent = null, path: String = "", default: RootData = null) -> RootData:
	for r: RootData in root_data_list:
		if r.is_root_or_path(root, path):
			return r
	return default

func has_data(root_data: RootData) -> bool:
	return get_data(root_data.root, root_data.path) != null

func path_get_data(path: String) -> RootData:
	for data: RootData in get_data_list():
		if data.is_path(path):
			return data
	return null

func has_path(path: String) -> bool:
	return path_get_data(path) != null

func root_get_data(root: RationalComponent) -> RootData:
	for data: RootData in get_data_list():
		if data.is_root(root):
			return data
	return null

func has_root(root: RationalComponent) -> bool:
	return root_get_data(root) != null

func has_root_or_path(root: RationalComponent, path: String) -> bool:
	return get_data(root, path) != null

func add_data(root_data: RootData) -> void:
	if not root_data or has_data(root_data): return
	
	root_data_list.push_back(root_data)
	
	root_data.request_edit.connect(_on_data_request_edit, CONNECT_APPEND_SOURCE_OBJECT)
	root_data.closed.connect(erase_data, CONNECT_APPEND_SOURCE_OBJECT | CONNECT_DEFERRED)
	
	data_added.emit(root_data)


func add_root(root: RationalComponent, path: String = "") -> void:
	if not root or has_root_or_path(root, path): return
	add_data(RootData.new(path if path else root.resource_path, root))


func add_path(path: String) -> void:
	if not path or has_path(path): return
	add_data(RootData.new(path))


func erase_data(data: RootData) -> void:
	if not data or not has_data(data): return
	root_data_list.erase(data)
	
	if edited_tree == data:
		set_edited_tree(null)
	
	if data.has_unsaved_changes() and data.is_external():
		data.save()
	
	data_erased.emit(data)

func erase_path(path: String) -> void:
	if not has_path(path): return
	erase_data(path_get_data(path))

func get_data_list() -> Array[RootData]:
	return root_data_list

func _on_file_moved(from: String, to: String) -> void:
	var data: RootData = path_get_data(from)
	if not data or not data.root: 
		return
	data.path = to


#endregion Paths/Roots

func _on_resource_removed(res: Resource) -> void:
	if res is RationalComponent and has_root(res):
		get_data(res).clear_path()

func _on_data_request_edit(data: RootData) -> void:
	edit_tree(data)


#region Save/Load

func get_save_path(file: String = FILENAME) -> String:
	return get_script().resource_path.get_base_dir().path_join(file)

func get_unsaved_status(scene_path: String) -> String:
	#var autosave: bool = Util.get_setting("autosave", true)
	#
	#if not autosave:
		#return "ERROR BUG: Autosave set to false."
	
	for rd: RootData in get_data_list():
		if not scene_path or rd.path.contains(scene_path): 
			rd.save()
	
	if not scene_path:
		save()
	
	
	return ""


func save() -> void:
	var root_data: Array[Dictionary]
	for rd: RootData in get_data_list():
		if rd.is_temp(): continue
		root_data.push_back(rd.serialize())
	
	var cfg: ConfigFile = ConfigFile.new()
	cfg.set_value(SECTION, KEY_ROOT_DATA, root_data)
	var err:= cfg.save(get_save_path())
	if err == OK:
		print_rich("[color=green]Cache saved %d roots.[/color]" % root_data.size())
	else:
		printerr("Rational cache save error: %s" % error_string(err))


func load() -> void:
	var cfg: ConfigFile = ConfigFile.new()
	var err:= cfg.load(get_save_path())
	if err != OK:
		printerr("Error loading Rational files: %s.\nCheck save file '%s'." % [error_string(err), get_save_path()])
		return
	
	var fs: EditorFileSystem = EditorInterface.get_resource_filesystem()
	while fs.is_scanning():
		await Engine.get_main_loop().process_frame
	
	for dict: Dictionary in cfg.get_value(SECTION, KEY_ROOT_DATA, []):
		add_data(RootData.deserialize(dict))

func save_data_as(data: RootData) -> void:
	if not data: return
	request_save_as.emit(data)

#endregion Save/Load
