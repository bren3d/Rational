@tool
extends GraphNode


const Util := preload("../util.gd")


const PORT_RADIUS: float = 7.0
const RADIUS_SIZE_INCREASE: float = 5.0

#@export_tool_button("djkf", "Missing")

signal component_children_changed
#signal component_tree_changed

var component: RationalComponent: set = set_component


@export var title_text: String:
	set(value):
		title_text = value
		if title_label:
			title_label.text = value

@export var text: String:
	set(value):
		text = value
		if label:
			label.text = " " if text.is_empty() else text

@export var icon: Texture2D:
	set(value):
		icon = value
		if icon_rect:
			icon_rect.texture = value


var layout_size: float:
	get: return size.y if horizontal else size.x


var icon_rect: TextureRect
var title_label: Label
var label: Label
var titlebar_hbox: HBoxContainer

var frames: RefCounted
var horizontal: bool = false
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


func _init(frames: RefCounted, horizontal: bool = false) -> void:
	self.frames = frames
	self.horizontal = horizontal
	
	custom_minimum_size = Vector2(50, 50) * EditorInterface.get_editor_scale()
	
	# For top port
	var top_port: Control = Control.new()
	add_child(top_port)

	icon_rect = TextureRect.new()
	icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon_rect.custom_minimum_size = Vector2(16.0, 16.0) * EditorInterface.get_editor_scale()
	icon_rect.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	icon_rect.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	titlebar_hbox = get_titlebar_hbox()
	
	title_label = Label.new()
	title_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	titlebar_hbox.add_child(title_label)
	
	label = Label.new()
	label.text = " " if text.is_empty() else text
	add_child(label)


func _ready() -> void:
	add_theme_color_override("close_color", Color.TRANSPARENT)
	add_theme_icon_override("close", ImageTexture.new())
	
	titlebar_hbox.get_child(0).queue_free()
	titlebar_hbox.alignment = BoxContainer.ALIGNMENT_BEGIN
	titlebar_hbox.add_child(icon_rect)
	
	title_label.add_theme_color_override("font_color", Color.WHITE)
	var title_font: Font = get_theme_font("title_font").duplicate()
	if title_font is FontVariation:
		title_font.variation_embolden = 1
	elif title_font is FontFile:
		title_font.font_weight = 600
	title_label.add_theme_font_override("font", title_font)

	title_label.text = title_text
	
	minimum_size_changed.connect(_on_size_changed)
	_on_size_changed.call_deferred()


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


func get_custom_input_port_position(horizontal: bool) -> Vector2:
	return Vector2(0, size.y / 2) if horizontal else Vector2(size.x / 2, 0)

func get_custom_output_port_position(horizontal: bool) -> Vector2:
	return Vector2(size.x, size.y / 2) if horizontal else Vector2(size.x / 2, size.y)


func set_status(status: int) -> void:
	match status:
		0: _set_stylebox_overrides(frames.panel_success, frames.titlebar_success)
		1: _set_stylebox_overrides(frames.panel_failure, frames.titlebar_failure)
		2: _set_stylebox_overrides(frames.panel_running, frames.titlebar_running)
		_: _set_stylebox_overrides(frames.panel_normal, frames.titlebar_normal)


## Left == parent port. Right == child(s) port.
func set_slots(left_enabled: bool, right_enabled: bool) -> void:
	set_slot(0, left_enabled, 0, Color.WHITE, right_enabled, 0, Color.WHITE)


func set_color(color: Color) -> void:
	set_slot_color_left(0, color)
	set_slot_color_right(0, color)


func update_display() -> void:
	title_text = component.resource_name if component else ""
	icon = Util.comp_get_icon(component) if component else null
	name = str(component.get_instance_id())


func set_component(val: RationalComponent) -> void:
	if component:
		component.changed.disconnect(_on_component_changed)
		
	component = val
	
	update_display()
	
	if component:
		component.changed.connect(_on_component_changed)


func _set_stylebox_overrides(panel_stylebox: StyleBox, titlebar_stylebox: StyleBox) -> void:
	if not has_theme_stylebox_override("panel") or panel_stylebox != frames.panel_normal:
		if panels_tween:
			panels_tween.kill()
		
		add_theme_stylebox_override("panel", panel_stylebox)
		add_theme_stylebox_override("titlebar", titlebar_stylebox)
	
	if panels_tween:
		return
	
	# Don't need to do anything if our colors are already the same as a normal
	var cur_panel_stylebox: StyleBox = get_theme_stylebox("panel")
	var cur_titlebar_stylebox: StyleBox = get_theme_stylebox("titlebar")
	if cur_panel_stylebox.bg_color == frames.panel_normal.bg_color:
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

func _on_size_changed():
	add_theme_constant_override("port_offset", 12 * EditorInterface.get_editor_scale() if horizontal else roundi(size.x))

func _on_component_changed() -> void:
	update_display()

func _draw() -> void:
	if not is_drawing_index: return
	var font: Font = title_label.get_theme_font(&"font")
	var font_size: int = size.y / 1.3
	#while font.get_height(font_size) < (size.y)*1.2:
		#font_size += 1
	var txt: String = str(current_index)
	var text_size: Vector2 = font.get_string_size(txt, 0, -1, font_size)
	var pos: Vector2 = Vector2((size.x - text_size.x) / 2.0, size.y - (size.y - text_size.y))
	
	draw_string_outline(font, pos, txt, 0, -1, font_size, 4)
	draw_string(font, pos, txt, 0, -1, font_size)
	
	
