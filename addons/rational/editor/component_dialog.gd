@tool
extends ConfirmationDialog

# Type of [hint='Abstract class for behavior tree components.']
# [color=#42ffc2ff][url=class_name:RationalComponent]RationalComponent[/url][/color][/hint] that manages children.

# EditorInterface.get_script_editor().goto_help(meta)

#var description_data: Dictionary[String, Dictionary]

const TITLE_DEFAULT: String = "Create Rational Node"

const ClassData := preload("../data/rational_class_data.gd")

@export var tree: Tree
@export var description_label: RichTextLabel
@export var line_edit: LineEdit
@export var menu_button: MenuButton

var class_data: ClassData

#var exclude_filters: PackedStringArray
var active_callback: Callable


func _init() -> void:
	hide()
	theme_changed.connect(_on_theme_changed)
	get_ok_button().disabled = true
	confirmed.connect(_on_confirmed)
	canceled.connect(_on_canceled)
	visibility_changed.connect(_on_visibility_changed, CONNECT_DEFERRED)
	title = TITLE_DEFAULT
	about_to_popup.connect(_on_about_to_popup, CONNECT_DEFERRED)
	min_size = Vector2i(300, 500) * EditorInterface.get_editor_scale()


func _ready() -> void:
	tree.item_selected.connect(_on_tree_item_selected)
	tree.item_activated.connect(_on_item_activated)
	line_edit.text_changed.connect(_on_filter_changed)
	description_label.meta_clicked.connect(_on_meta_clicked)
	description_label.custom_minimum_size.y = 100.0 * EditorInterface.get_editor_scale()
	menu_button.get_popup().id_pressed.connect(_on_menu_button_id_pressed)

## [param callback] should accept a single StringName as an argument. Moves [param at_position] down by title height.
func open(at_position: Vector2 = Vector2.ZERO, callback: Callable = Callable()) -> void:
	if visible: return
	if not about_to_popup.is_connected(_on_about_to_popup):
		about_to_popup.connect(_on_about_to_popup, CONNECT_DEFERRED)
	position = at_position
	active_callback = callback
	popup()


#func open_position(at_position: Vector2, callback: Callable = Callable()) -> void:
	#if visible: return
	#position = at_position
	#open(callback)

#func open_centered(callback: Callable = Callable()) -> void:
	#if visible: return
	#active_callback = callback
	#popup_centered()
	#popup_centered_ratio()
	

func popup_at_position(at_position: Vector2) -> void:
	popup(Rect2(at_position, size))

func add_class_item(_class: StringName, parent: TreeItem = null) -> void:
	var item: TreeItem = tree.create_item(parent)
	item.set_text(0, _class)
	item.set_selectable(0, not class_data.class_is_abstract(_class))
	item.set_metadata(0, class_data.class_get_script_path(_class))
	if not class_data.class_is_abstract(_class):
		item.set_icon(0, class_data.class_get_icon(_class))
	
	for inhereter: StringName in class_data.class_get_inhereters(_class):
		add_class_item(inhereter, item)


func refresh_tree() -> void:
	if not tree: return
	tree.clear()
	add_class_item(&"RationalComponent")
	expand_all()

func collapse_all() -> void:
	if not tree or not tree.get_root(): return
	for item: TreeItem in tree.get_root().get_children():
		item.call_recursive("set_collapsed", true)

func expand_all() -> void:
	if not tree or not tree.get_root(): return
	for item: TreeItem in tree.get_root().get_children():
		item.call_recursive("set_collapsed", false)


func class_get_description(_class: String) -> String:
	return "%s class description." % _class


func _on_tree_item_selected() -> void:
	var item: TreeItem = tree.get_selected()
	description_label.text = class_get_description(item.get_text(0)) if item else ""
	get_ok_button().disabled = not is_instance_valid(item)




func _on_confirmed() -> void:
	if not active_callback: return
	active_callback.call(get_selected_script_path())

func _on_canceled() -> void:
	pass


func _on_visibility_changed() -> void:
	if visible:
		line_edit.clear()
		line_edit.edit()
	else:
		active_callback = Callable()

func _on_about_to_popup() -> void:
	var window_rect: Rect2 = get_tree().root.get_visible_rect()
	var titlebar_height: int = get_theme_constant(&"title_height")
	position.x = clampi(position.x, window_rect.position.x, window_rect.end.x - size.x)
	position.y = clampi(position.y, window_rect.position.y + titlebar_height , window_rect.end.y - size.y + titlebar_height)

func item_apply_filter(item: TreeItem, filter_text: String) -> bool:
	var item_contains_filter: bool = filter_text == "" or item.get_text(0).containsn(filter_text)
	
	if item_contains_filter:
		item.call_recursive("set_visible", true)
		return true
	
	var any_child_visible: bool = false
	for child: TreeItem in item.get_children():
		any_child_visible = item_apply_filter(child, filter_text) or any_child_visible
	item.visible = any_child_visible
	
	return item.visible

func get_selected_script_path() -> StringName:
	return tree.get_selected().get_metadata(0) if tree and tree.get_selected() else &""

func _on_filter_changed(txt: String) -> void:
	if not tree or not tree.get_root(): return
	for item: TreeItem in tree.get_root().get_children():
		item_apply_filter(item, txt)

func _on_meta_clicked(meta: Variant) -> void:
	var meta_str: String = str(meta)
	hide()


func _on_item_activated() -> void:
	confirmed.emit()
	close_requested.emit()
	hide()

func _on_menu_button_id_pressed(id: int) -> void:
	match id:
		0: expand_all()
		1: collapse_all()

func _on_theme_changed() -> void:
	line_edit.right_icon = get_theme_icon(&"Search", &"EditorIcons")
	menu_button.icon = get_theme_icon(&"Modifiers", &"EditorIcons")
	tree.add_theme_constant_override(&"icon_max_width", 16.0 * EditorInterface.get_editor_scale())

func set_cache(cache: Object) -> void:
	class_data = Engine.get_singleton(&"Rational").class_data
	refresh_tree()
	class_data.class_data_updated.connect(refresh_tree)
