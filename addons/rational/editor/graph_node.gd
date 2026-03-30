@tool
extends GraphNode

const Util := preload("../util.gd")

#@export_tool_button("DFJ", "NewRoot")
const PORT_RADIUS: float = 7.0
const RADIUS_SIZE_INCREASE: float = 5.0

enum {ITEM_RENAME, ITEM_CHANGE_TYPE, ITEM_SEP1, ITEM_MAKE_ROOT, ITEM_COPY, ITEM_DUPLICATE}

signal component_children_changed
signal request_selection

var component: RationalComponent: set = set_component

@export var title_text: String:
	set(value):
		title_text = value
		title_label.text = value
		line_edit.text = value

@export var text: String:
	set(value):
		text = value
		label.text = " " if text.is_empty() else text

@export var icon: Texture2D:
	set(value):
		icon = value
		icon_rect.texture = value
		#line_edit.right_icon = value


var layout_size: float:
	get: return size.y if horizontal else size.x


var icon_rect: TextureRect
var title_label: Label
var line_edit: LineEdit
var label: Label
var titlebar_hbox: HBoxContainer
var menu: PopupMenu

var frames: RefCounted
var horizontal: bool = false : set = set_horizontal
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

var shortcuts: Dictionary[Shortcut, Callable]

func _init(frames: RefCounted, horizontal: bool = false) -> void:
	self.frames = frames
	self.horizontal = horizontal
	
	custom_minimum_size = Vector2(50, 50) * EditorInterface.get_editor_scale()
	
	# For top port
	var top_port: Control = Control.new()
	add_child(top_port)

	icon_rect = TextureRect.new()
	icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	icon_rect.custom_minimum_size = Vector2(16.0, 16.0) * EditorInterface.get_editor_scale()
	icon_rect.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	icon_rect.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	titlebar_hbox = get_titlebar_hbox()
	titlebar_hbox.get_child(0).queue_free()
	
	title_label = Label.new()
	title_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_label.hide()
	titlebar_hbox.add_child(title_label)
	
	line_edit = LineEdit.new()
	line_edit.alignment = HORIZONTAL_ALIGNMENT_CENTER
	line_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	line_edit.flat = true
	line_edit.editable = false
	line_edit.selecting_enabled = false
	line_edit.select_all_on_focus = true
	line_edit.expand_to_text_length = true
	line_edit.mouse_filter = Control.MOUSE_FILTER_IGNORE
	#line_edit.focus_mode = Control.FOCUS_NONE
	#line_edit.context_menu_enabled = false
	#line_edit.emoji_menu_enabled = false
	#line_edit.shortcut_keys_enabled = false
	line_edit.max_length = RationalComponent.NAME_MAX_LENGTH
	line_edit.add_theme_color_override("font_color", Color.WHITE)
	line_edit.add_theme_color_override("font_uneditable_color", Color.WHITE)
	
	var empty_stylebox: StyleBoxEmpty = StyleBoxEmpty.new()
	line_edit.add_theme_stylebox_override("normal", empty_stylebox)
	line_edit.add_theme_stylebox_override("read_only", empty_stylebox)
	#line_edit.add_theme_stylebox_override("read_only", Util.get_stylebox(&"normal", &"LineEdit"))
	#line_edit.theme_type_variation = &"TreeLineEdit"
	titlebar_hbox.add_child(line_edit)
	line_edit.editing_toggled.connect(_on_line_edit_editing_toggled)
	#line_edit.text_submitted.connect(_on_line_edit_text_submitted)
	^"theme_override_styles/read_only"
	
	
	titlebar_hbox.alignment = BoxContainer.ALIGNMENT_BEGIN
	titlebar_hbox.add_child(icon_rect)
	
	label = Label.new()
	label.text = " " if text.is_empty() else text
	add_child(label)
	
	#scaling_menus = true
	menu = PopupMenu.new()
	add_child(menu)

		
func rename() -> void:
	set_editable(true)
	line_edit.edit()
	line_edit.select_all()

func set_editable(editable: bool) -> void:
	line_edit.selecting_enabled = editable
	line_edit.editable = editable
	line_edit.mouse_filter = MOUSE_FILTER_IGNORE * int(not editable)
	line_edit.focus_mode = Control.FOCUS_ALL * int(editable)


func set_component_name(new_name: String) -> void:
	if not component or component.resource_name == new_name: return
	component.resource_name = new_name

func _on_line_edit_editing_toggled(is_editing: bool) -> void:
	print("LineEdit Toggled: %s" % is_editing)
	if is_editing: return
	set_editable(false)
	set_component_name(line_edit.text)
	reset_size()


func _ready() -> void:
	Util.add_menu_item(menu, "Rename", &"Rename", &"rename", null, ITEM_RENAME)
	shortcuts[Util.get_shortcut(&"rename")] = rename
	
	#menu.add_icon_item(get_theme_icon(&"Rename", &"EditorIcons"), "Rename", ITEM_RENAME, )
	#menu.set_item_shortcut(menu.item_count -1, Util.get_shortcut("rename"))
	
	menu.add_icon_item(get_theme_icon(&"RotateLeft", &"EditorIcons"), "Change Type...", ITEM_CHANGE_TYPE)
	menu.set_item_shortcut(menu.item_count -1, Util.get_shortcut("change_type"))
	
	menu.add_separator("")
	menu.add_icon_item(get_theme_icon(&"NewRoot", &"EditorIcons"), "Save as Root", ITEM_MAKE_ROOT)
	menu.set_item_shortcut(menu.item_count -1, Util.get_shortcut("change_type"))
	
	menu.id_pressed.connect(_on_menu_pressed)
	
	add_theme_color_override("close_color", Color.TRANSPARENT)
	add_theme_icon_override("close", ImageTexture.new())
	
	
	
	title_label.add_theme_color_override("font_color", Color.WHITE)
	var title_font: Font = Util.get_font(&"main", &"EditorFonts").duplicate()
	#if title_font is FontVariation:
		#title_font.variation_embolden = 1.0
	#elif title_font is FontFile:
		#title_font.font_weight = 600
	title_label.add_theme_font_override("font", title_font)
	line_edit.add_theme_font_override("font", title_font)
	
	line_edit.text = title_text
	title_label.text = title_text
	
	minimum_size_changed.connect(_on_size_changed)
	_on_size_changed.call_deferred()


func _on_menu_pressed(id: int) -> void:
	print("Menu Item Pressed: %s" % menu.get_item_text(id))
	match id:
		ITEM_RENAME:
			rename()
	

func _gui_input(event: InputEvent) -> void:
	if not event.is_pressed() or event.is_echo(): return
	
	if event is InputEventMouseButton:
		match event.button_index:
			MOUSE_BUTTON_LEFT:
				if not event.double_click or not titlebar_hbox.get_rect().has_point(event.position): return
				accept_event()
				rename()
			
			MOUSE_BUTTON_RIGHT when not MOUSE_BUTTON_MASK_RIGHT & event.button_mask:
				accept_event()
				selected = true
				if not event.shift_pressed and not event.ctrl_pressed:
					request_selection.emit()
				menu.position = get_viewport().position + Vector2i(event.global_position)
				menu.popup()

func _shortcut_input(event: InputEvent) -> void:
	if not event.is_pressed() or event.is_echo(): return
	for sc in shortcuts:
		if sc.matches_event(event):
			accept_event()
			shortcuts[sc].call()


func _draw_port(slot_index: int, port_position: Vector2i, left: bool, color: Color) -> void:
	var radius: float = PORT_RADIUS + (RADIUS_SIZE_INCREASE * float((left and is_left_port_hovered) or (not left and is_right_port_hovered)))
	const POINT_COUNT: int = 8
	const ANGLE_UP: float = PI/2.0
	const ANGLE_DOWN: float = 3.0/2.0 * PI
	const ANGLE_OFFSET: float = 0.2
	var tex: Texture2D = get_theme_icon(&"GuiGraphNodePort", &"EditorIcons")
	var sz:= tex.get_size()
	#var rect: Rect2 = Rect2(- sz.x / 2.0 * float(), tex.get_size())
	if horizontal:
		if left and is_slot_enabled_left(0):
			print(sz)
			var src_rect: Rect2 = Rect2(0, 0, tex.get_width()/2.0, tex.get_height())
			var start := Vector2(0, size.y/2.0) - tex.get_size()/2.0
			var rect:= Rect2(start, src_rect.size)
			#Rect2(0, size.y/2.0 - src_rect.size.y/2.0, 0, 0)
			draw_texture_rect_region(tex, rect, src_rect, Color.REBECCA_PURPLE,)
			#draw_circle(Vector2(0, size.y / 2), radius, color,)
			#draw_arc(Vector2(0, size.y / 2), radius/2.0, ANGLE_DOWN + ANGLE_OFFSET, ANGLE_UP - ANGLE_OFFSET , POINT_COUNT, color, radius, true)
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
	icon = Util.comp_get_icon(component)
	name = str(component.get_instance_id())
	tooltip_text = "ID: %s" % (component.get_instance_id() if component else "INVALID")


func set_component(val: RationalComponent) -> void:
	if component:
		component.changed.disconnect(_on_component_changed)
		component.children_changed.disconnect(component_children_changed.emit)
	
	component = val
	
	update_display()
	
	if component:
		component.changed.connect(_on_component_changed)
		component.children_changed.connect(component_children_changed.emit)


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
	var txt: String = str(current_index)
	var text_size: Vector2 = font.get_string_size(txt, 0, -1, font_size)
	var pos: Vector2 = Vector2((size.x - text_size.x) / 2.0, size.y - (size.y - text_size.y))
	
	draw_string_outline(font, pos, txt, 0, -1, font_size, 4)
	draw_string(font, pos, txt, 0, -1, font_size)

#func _get_tooltip(at_position: Vector2) -> String:
	#return "ID: %s" % component.get_instance_id() if component else "INVALID"

func set_horizontal(val: bool) -> void:
	horizontal = val
