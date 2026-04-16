@tool
extends GraphNode

const Util := preload("../util.gd")
const Style := preload("editor_style.gd")
const ComponentEditor := preload("component_editor.gd")
const TreePositionComponent := preload("tree_positioner.gd")

const INVALID_POSITION: Vector2 = Vector2(-999999, -999999)
const PORT_RADIUS: float = 7.0
const RADIUS_SIZE_INCREASE: float = 5.0

signal component_children_changed
signal component_property_edited(property: StringName, value: Variant, field: StringName, changing: bool)

var component: RationalComponent: set = set_component


@export var title_text: String:
	set(value):
		title_text = value
		line_edit.text = value

@export var icon: Texture2D:
	set(value):
		icon = value
		icon_rect.texture = value


var layout_size: float:
	get: return size.y if horizontal else size.x


var icon_rect: TextureRect
var line_edit: LineEdit
var titlebar_hbox: HBoxContainer

var hide_button: BaseButton

var container: MarginContainer
var editor: ComponentEditor

var horizontal: bool = false : set = set_horizontal
var arranged: bool = false

var root: bool = false

var positioner: TreePositionComponent = TreePositionComponent.new()
var arranged_position: Vector2 = INVALID_POSITION

var panels_tween: Tween

var is_left_port_hovered: bool = false:
	set(val):
		if is_left_port_hovered == val: return
		is_left_port_hovered = val
		queue_redraw()

var is_right_port_hovered: bool = false:
	set(val):
		if is_right_port_hovered == val: return
		is_right_port_hovered = val
		queue_redraw()

var is_drawing_index: bool = false:
	set(val):
		if is_drawing_index == val: return
		is_drawing_index = val
		queue_redraw()

var current_index: int = 0:
	set(val):
		if current_index == val: return
		current_index = val
		queue_redraw()

var parent: GraphNode: set = set_graph_parent
var children: Array[GraphNode]: set = set_graph_children

func _init(horizontal: bool = false) -> void:
	self.horizontal = horizontal
	positioner.item = self
	custom_minimum_size = Vector2(50, 50) * EditorInterface.get_editor_scale()
	
	icon_rect = TextureRect.new()
	icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	icon_rect.custom_minimum_size = Vector2(16.0, 16.0) * EditorInterface.get_editor_scale()
	icon_rect.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	icon_rect.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	
	titlebar_hbox = get_titlebar_hbox()
	titlebar_hbox.get_child(0).queue_free()
	
	#hide_button = Button.new()
	#hide_button.icon = Util.get_icon(&"GuiVisibilityVisible", &"EditorIcons")
	#hide_button.icon = Util.get_icon(&"GuiVisibilityHidden", &"EditorIcons")
	
	
	line_edit = LineEdit.new()
	line_edit.alignment = HORIZONTAL_ALIGNMENT_CENTER
	line_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	line_edit.flat = true
	line_edit.editable = false
	line_edit.selecting_enabled = false
	line_edit.select_all_on_focus = true
	line_edit.expand_to_text_length = true
	line_edit.mouse_filter = Control.MOUSE_FILTER_IGNORE
	line_edit.max_length = RationalComponent.NAME_MAX_LENGTH
	line_edit.add_theme_color_override("font_color", Color.WHITE)
	line_edit.add_theme_color_override("font_uneditable_color", Color.WHITE)
	
	var empty_stylebox: StyleBoxEmpty = StyleBoxEmpty.new()
	line_edit.add_theme_stylebox_override("normal", empty_stylebox)
	line_edit.add_theme_stylebox_override("read_only", empty_stylebox)

	titlebar_hbox.add_child(line_edit)
	line_edit.editing_toggled.connect(_on_line_edit_editing_toggled)
	
	titlebar_hbox.alignment = BoxContainer.ALIGNMENT_BEGIN
	titlebar_hbox.add_child(icon_rect)
	
	editor = ComponentEditor.new()
	container = MarginContainer.new()
	container.custom_minimum_size = Vector2(32.0, 32.0) * EditorInterface.get_editor_scale()
	container.theme_type_variation = &"MarginContainer4px"
	container.add_theme_constant_override(&"bottom_margin", 12)
	container.add_child(editor)
	add_child(container)
	
	resized.connect(_on_resized)
	position_offset_changed.connect(_on_position_offset_changed)

func _on_resized() -> void:
	if arranged:
		arranged_position = positioner.get_position()
		position_offset = arranged_position

func _on_position_offset_changed() -> void:
	arranged = arranged_position != INVALID_POSITION and position_offset == arranged_position

func arrange() -> void:
	arranged_position = positioner.get_position()
	position_offset = arranged_position
	arranged = true
	for child in children:
		child.arrange()

func set_graph_parent(val: GraphNode) -> void:
	parent = val
	positioner.parent = parent.positioner if parent else null

func set_graph_children(val: Array[GraphNode]) -> void:
	for child in children:
		if not child in val: continue
		child.parent = null
		
	children = val
	
	var positioner_children: Array[RefCounted]
	for child in children:
		child.parent = self
		positioner_children.push_back(child.positioner)
	
	positioner.children = positioner_children

func _ready() -> void:
	
	add_theme_color_override("close_color", Color.TRANSPARENT)
	add_theme_icon_override("close", ImageTexture.new())
	
	var title_font: Font = Util.get_font(&"main", &"EditorFonts").duplicate()
	line_edit.add_theme_font_override("font", title_font)
	
	line_edit.text = title_text

func is_inherited() -> bool:
	return not root and component and not component.is_built_in()

func get_component_class() -> StringName:
	return component.get_script().get_global_name() if component else &""

func rename() -> void:
	set_editable(true)

func set_editable(editable: bool) -> void:
	editable = editable and not is_inherited()
	line_edit.selecting_enabled = editable
	line_edit.editable = editable
	line_edit.mouse_filter = MOUSE_FILTER_IGNORE * int(not editable)
	line_edit.focus_mode = Control.FOCUS_ALL * int(editable)
	if editable:
		line_edit.edit()
		line_edit.select_all()



func set_component_name(new_name: String) -> void:
	if not component or component.resource_name == new_name: return
	component.resource_name = new_name


func _on_line_edit_editing_toggled(is_editing: bool) -> void:
	if not is_visible_in_tree() or is_editing: return
	set_editable(false)
	set_component_name(line_edit.text)
	reset_size()


func _draw_port(slot_index: int, port_position: Vector2i, left: bool, color: Color) -> void:
	var radius: float = PORT_RADIUS + (RADIUS_SIZE_INCREASE * float((left and is_left_port_hovered) or (not left and is_right_port_hovered)))
	const POINT_COUNT: int = 8
	const ANGLE_UP: float = PI/2.0
	const ANGLE_DOWN: float = 3.0/2.0 * PI
	const ANGLE_OFFSET: float = 0.2
	if horizontal:
		if left and is_slot_enabled_left(0):
			draw_arc(Vector2(0, size.y / 2), radius/2.0, ANGLE_DOWN + ANGLE_OFFSET, ANGLE_UP - ANGLE_OFFSET , POINT_COUNT, color, radius, true)
		elif not left and is_slot_enabled_right(0):
			draw_arc(Vector2(size.x, size.y / 2), radius/2.0, -ANGLE_UP - ANGLE_OFFSET, ANGLE_UP + ANGLE_OFFSET, POINT_COUNT, color, radius, true)
	else:
		if left and is_slot_enabled_left(0):
			draw_arc(Vector2(size.x / 2, 0), radius/2.0, -PI - ANGLE_OFFSET, ANGLE_OFFSET, POINT_COUNT, color, radius, true)
		elif not left and is_slot_enabled_right(0):
			draw_arc(Vector2(size.x / 2, size.y), radius/2.0, - ANGLE_OFFSET, PI + ANGLE_OFFSET, POINT_COUNT, color, radius, true)

## For GraphEdit use.
func get_titlebar_rect() -> Rect2:
	return Rect2(position + titlebar_hbox.position, titlebar_hbox.size)

func get_input_position() -> Vector2:
	return Vector2(0, size.y / 2) if horizontal else Vector2(size.x / 2, 0)

func get_output_position() -> Vector2:
	return Vector2(size.x, size.y / 2) if horizontal else Vector2(size.x / 2, size.y)

func get_port_position(left: bool) -> Vector2:
	return get_input_position() if left else get_output_position()

func set_status(status: int) -> void:
	match status:
		0: set_stylebox_overrides(Style.panel_success, Style.titlebar_success)
		1: set_stylebox_overrides(Style.panel_failure, Style.titlebar_failure)
		2: set_stylebox_overrides(Style.panel_running, Style.titlebar_running)
		_: set_stylebox_overrides(Style.panel_normal, Style.titlebar_normal)


## Left == parent port. Right == children port.
func set_slots(left_enabled: bool, right_enabled: bool) -> void:
	if left_enabled != is_slot_enabled_left(0) or right_enabled != is_slot_enabled_right(0):
		set_slot(0, left_enabled, 0, Color.WHITE, right_enabled, 0, Color.WHITE)


func update_display() -> void:
	title_text = component.resource_name if component else ""
	icon = Util.comp_get_icon(component)
	
	name = str(component.get_instance_id())
	icon_rect.tooltip_text = Util.comp_get_class(component) if component else ""


func set_component(val: RationalComponent) -> void:
	if component:
		component.changed.disconnect(_on_component_changed)
		component.script_changed.disconnect(_on_component_script_changed)
		component.children_changed.disconnect(_on_component_children_changed)
	
	component = val
	update_display()
	set_slots(not root, component is Composite)
	
	editor.visible = not is_inherited()
	editor.update_display(val if editor.visible else null)
	resizable = editor.visible and editor.has_properties()
	
	if component:
		component.changed.connect(_on_component_changed)
		component.script_changed.connect(_on_component_script_changed, CONNECT_DEFERRED)
		component.children_changed.connect(_on_component_children_changed)

func _on_component_changed() -> void:
	update_display()

func _on_component_children_changed() -> void:
	component_children_changed.emit()

func _on_component_script_changed() -> void:
	if not is_inside_tree():
		if not tree_entered.is_connected(_on_component_script_changed):
			tree_entered.connect(_on_component_script_changed, CONNECT_ONE_SHOT)
		return
	set_slots(component != get_parent().get_root_component(), component is Composite)
	update_display() 

func _draw() -> void:
	if is_drawing_index:
		draw_index()

func draw_index() -> void:
	var font: Font = line_edit.get_theme_font(&"font")
	var font_size: int = size.y / 1.3
	var txt: String = str(current_index)
	var text_size: Vector2 = font.get_string_size(txt, 0, -1, font_size)
	var pos: Vector2 = Vector2((size.x - text_size.x) / 2.0, size.y - (size.y - text_size.y))
	
	draw_string_outline(font, pos, txt, 0, -1, font_size, 4)
	draw_string(font, pos, txt, 0, -1, font_size)

func _get_tooltip(at_position: Vector2) -> String:
	return ("ID: %s" % component.get_instance_id()) if component else ""

func set_horizontal(val: bool) -> void:
	horizontal = val


func set_stylebox_overrides(panel_stylebox: StyleBox, titlebar_stylebox: StyleBox) -> void:
	if not has_theme_stylebox_override("panel") or panel_stylebox != Style.panel_normal:
		if panels_tween:
			panels_tween.kill()
		
		add_theme_stylebox_override("panel", panel_stylebox)
		add_theme_stylebox_override("titlebar", titlebar_stylebox)
	
	if panels_tween:
		return
	
	# Don't need to do anything if our colors are already the same as a normal
	var cur_panel_stylebox: StyleBox = get_theme_stylebox("panel")
	var cur_titlebar_stylebox: StyleBox = get_theme_stylebox("titlebar")
	if cur_panel_stylebox.bg_color == Style.panel_normal.bg_color:
		return
	
	# Apply a duplicate of our current panels that we can tween
	add_theme_stylebox_override("panel", cur_panel_stylebox.duplicate())
	add_theme_stylebox_override("titlebar", cur_titlebar_stylebox.duplicate())
	cur_panel_stylebox = get_theme_stylebox("panel")
	cur_titlebar_stylebox = get_theme_stylebox("titlebar")
	
	# Going back to normal is a fade
	panels_tween = create_tween().set_parallel()
	panels_tween.tween_property(cur_panel_stylebox, "bg_color", panel_stylebox.bg_color, 1.0)
	panels_tween.tween_property(cur_panel_stylebox, "border_color", panel_stylebox.border_color, 1.0)
	panels_tween.tween_property(cur_titlebar_stylebox, "bg_color", panel_stylebox.bg_color, 1.0)
	panels_tween.tween_property(cur_titlebar_stylebox, "border_color", panel_stylebox.border_color, 1.0)
