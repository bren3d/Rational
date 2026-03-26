@tool
extends ConfirmationDialog

# Type of [hint='Abstract class for behavior tree components.']
# [color=#42ffc2ff][url=class_name:RationalComponent]RationalComponent[/url][/color][/hint] that manages children.

# EditorInterface.get_script_editor().goto_help(meta)

signal root_created(root: RationalComponent)
signal node_created(node: RationalComponent)

@export var tree: Tree
@export var description_label: RichTextLabel
@export var line_edit: LineEdit
@export var menu_button: MenuButton

var is_creating_root: bool = false:
	set(val):
		if is_creating_root == val: return
		is_creating_root = val
		title = "Create Root Node" if val else "Create Rational Node"

var class_data: Dictionary[String, Dictionary]

var description_data: Dictionary[String, Dictionary]

func _init() -> void:
	hide()
	theme_changed.connect(_on_theme_changed)
	get_ok_button().disabled = true
	confirmed.connect(_on_confirmed)
	canceled.connect(_on_canceled)
	visibility_changed.connect(_on_visibility_changed, CONNECT_DEFERRED)

func _ready() -> void:
	
	update_class_data()
	update_tree()
	
	EditorInterface.get_resource_filesystem().script_classes_updated.connect(update_class_data)
	
	tree.item_selected.connect(_on_tree_item_selected)
	tree.item_activated.connect(_on_item_activated)
	line_edit.text_changed.connect(_on_filter_changed)
	description_label.meta_clicked.connect(_on_meta_clicked)
	menu_button.get_popup().id_pressed.connect(_on_menu_button_id_pressed)
	
	
	const BASE_MIN_SIZE: Vector2i =  Vector2i(300, 500)
	const BASE_DESCRIPTION_MIN_HEIGHT: float = 64.0
	min_size = BASE_MIN_SIZE * EditorInterface.get_editor_scale()
	description_label.custom_minimum_size.y = BASE_DESCRIPTION_MIN_HEIGHT * EditorInterface.get_editor_scale()
	
	
	

func open(is_new_root: bool = false) -> void:
	if visible:
		return
	
	is_creating_root = is_new_root
	
	popup_at_position(get_mouse_position())


func popup_at_position(at_position: Vector2) -> void:
	var window_rect: Rect2 = get_tree().root.get_visible_rect()
	var id: int = DisplayServer.get_window_at_screen_position(position)
	var titlebar_height: int = DisplayServer.window_get_title_size(title, id).y
	popup(Rect2(
		clampi(at_position.x, window_rect.position.x, window_rect.end.x - size.x),
		clampi(at_position.y, window_rect.position.y + titlebar_height , window_rect.end.y - size.y + titlebar_height),
		size.x,
		size.y
	))


func create_node(node_class: String) -> void:
	var script: Script = class_get_script(node_class)
	
	if not script:
		printerr("Could not find script for class '%s'." % node_class)
		return
		
	if script.is_abstract():
		printerr("Cannot instance abstract class '%s'." % node_class)
		return
	
	var node: RationalComponent = script.new()
	node.resource_name = node_class
	
	if is_creating_root:
		root_created.emit(node)
	
	else:
		node_created.emit(node)


func add_class_data(data: Dictionary) -> void:
	var icon: Texture2D = load(data.icon) if data.icon else class_data.get(data.base, {}).get("icon")
	var script: Script = load(data.path)
	class_data[data.class] = data.duplicate()
	class_data[data.class].icon = icon
	class_data[data.class].script = script
	class_data[data.class].is_abstract = script.is_abstract()


func update_class_data() -> void:
	class_data.clear()
	
	var class_list: Array[Dictionary] = ProjectSettings.get_global_class_list()
	
	for dict: Dictionary in class_list:
		if dict.class != &"RationalComponent": continue
		add_class_data(dict)
	
	var base_classes: Array[StringName] = [&"RationalComponent"]
	while not base_classes.is_empty():
		var new_bases: Array[StringName] = []
		for dict: Dictionary in class_list:
			if dict.base in base_classes:
				new_bases.push_back(dict.class)
				add_class_data(dict)
		base_classes = new_bases


func add_class_item(_class: String, parent: TreeItem = null) -> void:
	if not _class in class_data:
		printerr("No data found for class '%s'." % _class)
		return
	
	var data: Dictionary = class_data.get(_class, {"class": "INVALID", "icon": null, "is_abstract": true, "base": ""})
	var item: TreeItem = tree.create_item(parent)
	item.set_text(0, data.class)
	item.set_selectable(0, not data.is_abstract)
	if not data.is_abstract:
		item.set_icon(0, data.icon)
	
	for dict: Dictionary in class_data.values():
		if dict.base == _class:
			add_class_item(dict.class, item)


func update_tree() -> void:
	if not tree: return
	tree.clear()
	add_class_item("RationalComponent")
	expand_all()

func collapse_all() -> void:
	tree.get_root().call_recursive("set_collapsed", true)

func expand_all() -> void:
	tree.get_root().call_recursive("set_collapsed", false)


func class_get_description(_class: String) -> String:
	return "%s class description." % _class


func class_get_script(_class: String) -> Script:
	if not _class in class_data or not class_data[_class].get("script"):
		for dict: Dictionary in ProjectSettings.get_global_class_list():
			if dict.class == _class:
				return load(dict.path)
	
	return class_data.get(_class, {}).get("script")


func _on_tree_item_selected() -> void:
	var item: TreeItem = tree.get_selected()
	description_label.text = class_get_description(item.get_text(0)) if item else ""
	get_ok_button().disabled = not is_instance_valid(item)


func _on_confirmed() -> void:
	var item: TreeItem = tree.get_selected()
	if not item: return
	create_node(item.get_text(0))


func _on_canceled() -> void:
	is_creating_root = false


func _on_visibility_changed() -> void:
	if visible:
		line_edit.grab_focus()
		line_edit.select()
	else:
		is_creating_root = false

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
	meta = str(meta)

	hide()
	#print("Going to: ", meta)
	
	#printt(type_string(typeof(meta)), meta,)

func _on_item_activated() -> void:
	confirmed.emit()
	close_requested.emit()
	hide()

func _on_menu_button_id_pressed(id: int) -> void:
	if id == 0:
		expand_all()
	elif id == 1:
		collapse_all()

func _on_theme_changed() -> void:
	line_edit.right_icon = get_theme_icon(&"Search", &"EditorIcons")
	menu_button.icon = get_theme_icon(&"Modifiers", &"EditorIcons")

	var font: Font = description_label.get_theme_font("font")
	if not font:
		print("NO FONT!!!!!")
	else:
		description_label.custom_minimum_size.y = font.get_height(description_label.get_theme_font_size("normal_font_size")) * 3.2
	tree.add_theme_constant_override(&"icon_max_width", line_edit.right_icon.get_width())
