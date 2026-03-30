@tool
extends PanelContainer

const Util:= preload("../util.gd")
const Cache:= preload("../data/cache.gd")
#@export_tool_button("dkfjalk", "Back")

signal request_floating


@export var root_file_tree: Tree
@export var tree_display: Tree
@export var make_floating_button: Button
@export var add_root_button: Button
@export var collapse_panel_container: PanelContainer
@export var panel_collapse_button: Button
@export var tree_panel: VSplitContainer
@export var graph_edit: GraphEdit

var file_dialog: EditorFileDialog

var floating_window: Window

var toggle_panel_shortcut: Shortcut
#shortcuts[editor_settings.get_shortcut("canvas_item_editor/center_selection")]
var shortcuts: Dictionary[Shortcut, Callable]

var cache: Cache

var edited_tree: RootData:
	get: return cache.edited_tree if cache else null

var root_to_be_saved: RootData


func _init() -> void:
	file_dialog = EditorFileDialog.new()
	file_dialog.title = "Save Rational Component"
	file_dialog.add_filter("*.tres", "RationalComponent")
	file_dialog.add_filter("*.res", "RationalComponent")
	file_dialog.filters = PackedStringArray(["*.res,*.tres;Rational Files;resource/res,resource/tres"]) # ["*.res", "*.tres"]
	add_child(file_dialog)
	file_dialog.file_selected.connect(_on_file_selected)
	file_dialog.canceled.connect(_on_file_dialog_canceled, CONNECT_DEFERRED)


func _ready() -> void:
	panel_collapse_button.pressed.connect(_on_panel_collapse_pressed)
	init_shortcuts()


func set_cache(_cache: Cache) -> void:
	cache = _cache
	cache.edited_tree_changed.connect(_on_edited_tree_changed)
	cache.request_save_as.connect(save_as)

func _on_edited_tree_changed(data: RootData) -> void:
	graph_edit.set_active_root(data)
	EditorInterface.set_main_screen_editor("Rational")

func save_as(data: RootData) -> void:
	if not data: return
	file_dialog.current_file = ""
	if data.path:
		if DirAccess.dir_exists_absolute(data.path.get_base_dir()):
			file_dialog.current_dir = data.path.get_base_dir()
		file_dialog.current_file = data.path.get_file().get_slice(".", 0) + "_copy.tres"
		data = data.duplicate(false)
	
	root_to_be_saved = data
	if not file_dialog.current_file:
		file_dialog.current_file = data.name.to_snake_case() + "_copy.tres"
	
	file_dialog.popup_file_dialog()

func _on_file_selected(path: String) -> void:
	if not root_to_be_saved: return
	if ResourceLoader.exists(path):
		# TODO: Overwrite existing component.
		return
	
	root_to_be_saved.path = path
	var err:= root_to_be_saved.save(path)
	
	if err != OK:
		printerr("Error saving component (%s) at path '%s'" % [root_to_be_saved, path])
		return
	
	cache.add_data(root_to_be_saved)


func _on_file_dialog_canceled() -> void:
	root_to_be_saved = null

func edit(rational_object: Object) -> void:
	if rational_object is RationalTree:
		edit_tree(rational_object)
	elif rational_object is RationalComponent:
		edit_root(rational_object)

func edit_tree(tree: RationalTree) -> void:
	cache.edit_rational_tree(tree)

func edit_root(root: RationalComponent) -> void:
	cache.edit_root(root)
	EditorInterface.set_main_screen_editor("Rational")


func init_shortcuts() -> void:
	var editor_settings:= EditorInterface.get_editor_settings()
	
	var file_panel_shortcut: Shortcut = editor_settings.get_shortcut("script_editor/toggle_files_panel")
	panel_collapse_button.tooltip_text = "Toggle panel" + (" (%s)" % file_panel_shortcut.get_as_text() if file_panel_shortcut else "")
	shortcuts[file_panel_shortcut] = toggle_file_panel
	shortcuts[editor_settings.get_shortcut("script_editor/make_floating")] = make_floating_button.set_pressed.bind(true)
	
	shortcuts.erase(null)


func _shortcut_input(event: InputEvent) -> void:
	if not event.is_pressed() or event.is_echo(): return
	for sc: Shortcut in shortcuts:
		if sc.matches_event(event):
			accept_event()
			shortcuts[sc].call()
			return


func toggle_file_panel() -> void:
	tree_panel.visible = !tree_panel.visible
	panel_collapse_button.icon = get_theme_icon(&"Back" if tree_panel.visible else &"Forward", &"EditorIcons") 


func _on_panel_collapse_pressed() -> void:
	toggle_file_panel()

func apply_theme() -> void:
	panel_collapse_button.icon = get_theme_icon(&"Back" if tree_panel.visible else &"Forward", &"EditorIcons")
	
	if has_theme_stylebox(&"panel", &"PanelForeground"):
		var style_box: StyleBox = get_theme_stylebox(&"panel", &"PanelForeground").duplicate()
		style_box.set(&"corner_radius_bottom_left", 0)
		style_box.set(&"corner_radius_top_left", 0)
		style_box.set_content_margin_all(0)
		collapse_panel_container.add_theme_stylebox_override(&"panel", style_box)
	
	
	make_floating_button.icon = get_theme_icon(&"MakeFloating", &"EditorIcons")
	var icon_width: int = make_floating_button.icon.get_width()

	
	%RootListFilter.right_icon = get_theme_icon(&"Search", &"EditorIcons")
	%TreeFilter.right_icon = %RootListFilter.right_icon
	#for line_edit: LineEdit in find_children("*", "LineEdit"):
	
	root_file_tree.add_theme_constant_override(&"icon_max_width", icon_width)
	tree_display.add_theme_constant_override(&"icon_max_width", icon_width)
