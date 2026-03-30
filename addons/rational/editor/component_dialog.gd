@tool
extends ConfirmationDialog

# Type of [hint='Abstract class for behavior tree components.']
# [color=#42ffc2ff][url=class_name:RationalComponent]RationalComponent[/url][/color][/hint] that manages children.

# EditorInterface.get_script_editor().goto_help(meta)

#var description_data: Dictionary[String, Dictionary]

const TITLE_DEFAULT: String = "Create Rational Node"

const ClassData := preload("../data/rational_class_data.gd")

enum {MODE_INVALID, MODE_CREATE, MODE_NEW_ROOT, MODE_SELECT_CLASS,}

signal class_selected(_class: StringName)
signal root_created(root: RationalComponent)
signal node_created(node: RationalComponent)

@export var tree: Tree
@export var description_label: RichTextLabel
@export var line_edit: LineEdit
@export var menu_button: MenuButton

#var is_creating_root: bool = false:
	#set(val):
		#if is_creating_root == val: return
		#is_creating_root = val
		#title = "Create Root Node" if val else "Create Rational Node"

var class_data: ClassData

var dialog_mode: int = MODE_INVALID: set = set_dialog_mode

func set_dialog_mode(val: int) -> void:
	dialog_mode = val
	match dialog_mode:
		MODE_CREATE:
			title = "Create Rational Node"

func _init() -> void:
	hide()
	theme_changed.connect(_on_theme_changed)
	get_ok_button().disabled = true
	confirmed.connect(_on_confirmed)
	canceled.connect(_on_canceled)
	visibility_changed.connect(_on_visibility_changed, CONNECT_DEFERRED)
	title = TITLE_DEFAULT


func _ready() -> void:
	#refresh_tree()
	
	tree.item_selected.connect(_on_tree_item_selected)
	tree.item_activated.connect(_on_item_activated)
	line_edit.text_changed.connect(_on_filter_changed)
	description_label.meta_clicked.connect(_on_meta_clicked)
	menu_button.get_popup().id_pressed.connect(_on_menu_button_id_pressed)
	
	
	
	min_size = Vector2i(300, 500) * EditorInterface.get_editor_scale()
	description_label.custom_minimum_size.y = 100.0 * EditorInterface.get_editor_scale()


func open(_mode: int) -> void:
	if visible: return
	
	#is_creating_root = is_new_root
	
	popup_at_position(get_mouse_position())

func open_at_position(_mode: int, at_position: Vector2 = Vector2.ZERO) -> void:
	pass


func create_node(node_class: StringName) -> void:
	var script: Script = class_data.class_get_script(node_class)
	
	if not script:
		printerr("Could not find script for class '%s'." % node_class)
		return
		
	if script.is_abstract():
		printerr("Cannot instance abstract class '%s'." % node_class)
		return
	
	var node: RationalComponent = script.new()
	node.resource_name = node_class
	
	match dialog_mode:
		MODE_NEW_ROOT:
			root_created.emit(node)
		_, MODE_CREATE:
			node_created.emit(node)




func add_class_item(_class: StringName, parent: TreeItem = null) -> void:
	var item: TreeItem = tree.create_item(parent)
	item.set_text(0, _class)
	item.set_selectable(0, not class_data.class_is_abstract(_class))
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
	var item: TreeItem = tree.get_selected()
	if not item: return
	
	# TODO: ADD INVALID CHECK
	
	if dialog_mode == MODE_SELECT_CLASS:
		class_selected.emit(item.get_text(0))
		return
		
	create_node(item.get_text(0))


func _on_canceled() -> void:
	dialog_mode = MODE_INVALID


func _on_visibility_changed() -> void:
	if visible:
		line_edit.clear()
		line_edit.edit()
	else:
		set_dialog_mode.call_deferred(MODE_INVALID)


func popup_at_position(at_position: Vector2) -> void:
	var window_rect: Rect2 = get_tree().root.get_visible_rect()
	var titlebar_height: int = DisplayServer.window_get_title_size(title, DisplayServer.get_window_at_screen_position(position)).y
	popup(Rect2(
		clampi(at_position.x, window_rect.position.x, window_rect.end.x - size.x),
		clampi(at_position.y, window_rect.position.y + titlebar_height , window_rect.end.y - size.y + titlebar_height),
		size.x,
		size.y
	))


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

func _on_filter_changed(txt: String) -> void:
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
	tree.add_theme_constant_override(&"icon_max_width", line_edit.right_icon.get_width())

func set_cache(cache: Object) -> void:
	class_data = cache.class_data
	refresh_tree()
	class_data.class_data_updated.connect(refresh_tree)
