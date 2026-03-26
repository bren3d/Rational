@tool
extends PanelContainer

const Cache:= preload("../data/cache.gd")
#@export_tool_button("dkfjalk", "Back")

@export var root_file_tree: Tree
@export var tree_display: Tree
@export var make_floating_button: Button
@export var add_root_button: Button
@export var collapse_panel_container: PanelContainer
@export var panel_collapse_button: Button
@export var tree_panel: VSplitContainer
@export var graph_edit: GraphEdit

var floating_window: Window

var shortcuts: Array[Shortcut]

var toggle_panel_shortcut: Shortcut

var cache: Cache

var edited_tree: RootData:
	get: return cache.edited_tree if cache else null

func _ready() -> void:
	make_floating_button.pressed.connect(_on_make_floating)
	panel_collapse_button.pressed.connect(_on_panel_collapse_pressed)
	
	toggle_panel_shortcut = EditorInterface.get_editor_settings().get_shortcut("script_editor/toggle_files_panel")
	panel_collapse_button.tooltip_text = "Toggle panel" + (" (%s)" % toggle_panel_shortcut.get_as_text() if toggle_panel_shortcut else "")


func init_cache(cache: Cache) -> void:
	self.cache = cache
	propagate_call(&"set_cache", [cache])
	cache.edited_tree_changed.connect(_on_edited_tree_changed)

func _on_edited_tree_changed(data: RootData) -> void:
	graph_edit.set_active_root(data)
	EditorInterface.set_main_screen_editor("Rational")

func prompt_save_as(data: RootData) -> void:
	# TODO
	pass

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

func _gui_input(event: InputEvent) -> void:
	if not event.is_pressed() or event.is_echo(): return
	if toggle_panel_shortcut and toggle_panel_shortcut.matches_event(event):
		_on_panel_collapse_pressed()
		accept_event()

func apply_theme() -> void:
	panel_collapse_button.icon = get_theme_icon(&"Back" if tree_panel.visible else &"Forward", &"EditorIcons")
	
	var style_box: StyleBox = get_theme_stylebox(&"panel", &"PanelForeground")
	if style_box:
		style_box = style_box.duplicate()
		style_box.set(&"corner_radius_bottom_left", 0)
		style_box.set(&"corner_radius_top_left", 0)
		style_box.set_content_margin_all(0)
		collapse_panel_container.add_theme_stylebox_override(&"panel", style_box)
	
	make_floating_button.icon = get_theme_icon(&"MakeFloating", &"EditorIcons")
	var icon_width: int = make_floating_button.icon.get_width()

	for line_edit: LineEdit in find_children("*", "LineEdit"):
		line_edit.right_icon = get_theme_icon(&"Search", &"EditorIcons")
	
	root_file_tree.add_theme_constant_override(&"icon_max_width", icon_width)
	tree_display.add_theme_constant_override(&"icon_max_width", icon_width)



func _on_panel_collapse_pressed() -> void:
	tree_panel.visible = !tree_panel.visible
	panel_collapse_button.icon = get_theme_icon(&"Back" if tree_panel.visible else &"Forward", &"EditorIcons") 


#region Floating Window

func _on_make_floating() -> void:
	if EditorInterface.get_editor_main_screen() != get_parent() and not floating_window:
		return
		
	if floating_window:
		_on_window_close_requested()
		return

	make_floating_button.hide()
	var border_size := Vector2(4, 4) * EditorInterface.get_editor_scale()
	var editor_main_screen := EditorInterface.get_editor_main_screen()
	get_parent().remove_child(self)
	
	floating_window = Window.new()

	var panel := Panel.new()
	panel.add_theme_stylebox_override(
		"panel",
		EditorInterface.get_base_control().get_theme_stylebox("PanelForeground", "EditorStyles")
	)
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	floating_window.add_child(panel)

	var margin := MarginContainer.new()
	margin.add_child(self)
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_right", border_size.x)
	margin.add_theme_constant_override("margin_left", border_size.x)
	margin.add_theme_constant_override("margin_top", border_size.y)
	margin.add_theme_constant_override("margin_bottom", border_size.y)
	panel.add_child(margin)

	floating_window.title = "Rational"
	floating_window.wrap_controls = true
	floating_window.min_size = Vector2i(600, 350)
	floating_window.size = size
	floating_window.position = editor_main_screen.global_position
	floating_window.transient = true
	floating_window.close_requested.connect(_on_window_close_requested)
	
	EditorInterface.set_main_screen_editor("2D")
	EditorInterface.get_base_control().add_child(floating_window)


func _on_window_close_requested() -> void:
	get_parent().remove_child(self)
	EditorInterface.set_main_screen_editor("Rational")
	EditorInterface.get_editor_main_screen().add_child(self)
	floating_window.queue_free()
	floating_window = null
	make_floating_button.show()


func close() -> void:
	if floating_window:
		floating_window.queue_free()
	else:
		queue_free()


func make_visible(is_visible: bool) -> void:
	if floating_window:
		floating_window.grab_focus()
		#EditorInterface.set_main_screen_editor.call_deferred("2D")
	else:
		visible = is_visible

#endregion
