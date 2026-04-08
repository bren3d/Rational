@tool
extends PopupMenu

const Util:= preload("../util.gd")

enum {
	## No items, menu will be empty.
	ITEM_NONE = 0,
	
	## Add child component to parent.
	ITEM_ADD_CHILD = 1,
	
	## Cut selected components.
	ITEM_CUT = 2,
	
	## Copy selected components.
	ITEM_COPY = 4, 
	
	## Paste clipboard contents as children to selected component.
	ITEM_PASTE = 8,
	
	## Duplicate selected components.
	ITEM_DUPLICATE = 16, 
	
	## Duplicate selected component.
	ITEM_RENAME = 32, 
	
	## Change type of selected component.
	ITEM_CHANGE_TYPE = 64, 
	
	## Save selected component as the root of its own tree.
	ITEM_SAVE_AS_ROOT = 128, 
	
	## Open Class documentation for this component.
	ITEM_DOCUMENTATION = 256, 
	
	## Delete selected components.
	ITEM_DELETE = 512,
	
	## Add node to selected spot in editor.
	ITEM_ADD_NODE_HERE = 1024,
	
	## Instantiate another root to selected spot in editor.
	ITEM_INSTANTIATE_NODE_HERE = 2048,
	
	
	## Instantiate another root as a child to selected component.
	ITEM_INSTANTIATE_NODE = 4096,
	
	## Paste clipboard contents to selected spot in editor.
	ITEM_PASTE_HERE = 8192,
	
	## Paste clipboard contents as sibling to selected node.
	ITEM_PASTE_AS_SIBLING = 16384,
	
	## Move selected component up the tree.
	ITEM_MOVE_UP = 32768,
	
	## Move selected component down the tree.
	ITEM_MOVE_DOWN = 65536,
	
	## Reparent selected component.
	ITEM_REPARENT = 131072,
	
	## Move selected node(s) to a position in editor.
	ITEM_MOVE_NODE_HERE = 262144,
	
	## Reveal Component in the editor window.
	ITEM_SHOW_IN_EDITOR = 524288,

	## ITEM_CUT | ITEM_COPY | ITEM_DUPLICATE | ITEM_RENAME | ITEM_CHANGE_TYPE | ITEM_DOCUMENTATION | ITEM_DELETE
	ITEMS_DEFAULT = 886,
	
	## ITEM_ADD_NODE_HERE | ITEM_INSTANTIATE_NODE_HERE | ITEM_MOVE_NODE_HERE | ITEM_PASTE_HERE
	ITEMS_HERE = 273408,
	
	## All possible items.
	ITEMS_ALL = 2147483648,
}

func _init() -> void:
	index_pressed.connect(_on_index_pressed)


func popup_at(options: int, at_position: Vector2) -> void:
	set_menu_options(options)
	popup(Rect2(at_position, Vector2.ZERO))


func create_item(label: String, icon: StringName = &"", shortcut: StringName = "", id: int = -1, metadata: Variant = null) -> void:
	add_item(label, id)
	if icon:
		set_item_icon(item_count - 1, Util.get_icon(icon))
	if shortcut:
		set_item_shortcut(item_count - 1, Util.get_shortcut(shortcut))
		set_item_accelerator(item_count - 1, Util.get_accel(shortcut))
	if metadata != null:
		set_item_metadata(item_count -1, metadata)

func set_menu_options(options: int = ITEM_NONE) -> void:
	clear()
	if not options: return
	#
	if options & ITEM_ADD_NODE_HERE:
		create_item("Add Component Here...", &"Add", &"add_child", ITEM_ADD_NODE_HERE)
	if options & ITEM_INSTANTIATE_NODE_HERE:
		create_item("Instantiate Component Here...", &"Instance", &"instantiate_child",ITEM_INSTANTIATE_NODE_HERE)
	if options & ITEM_PASTE_HERE:
		create_item("Paste Component(s) Here", &"ActionPaste", &"paste", ITEM_PASTE_HERE)
	if options & ITEM_MOVE_NODE_HERE:
		create_item("Move Component(s) Here", &"ToolMove", &"", ITEM_MOVE_NODE_HERE)
	if options & ITEM_ADD_CHILD:
		create_item("Add Child...", &"Add", &"add_child",ITEM_ADD_CHILD)
	if options & ITEM_INSTANTIATE_NODE:
		create_item("Instantiate Child...", &"Instance", &"instantiate_child",ITEM_INSTANTIATE_NODE)
	if item_count and not is_item_separator(item_count - 1):
		add_separator("")
	if options & ITEM_CUT:
		create_item("Cut", &"ActionCut", &"cut",ITEM_CUT)
	if options & ITEM_COPY:
		create_item("Copy", &"ActionCopy", &"copy",ITEM_COPY)
	if options & ITEM_PASTE:
		create_item("Paste", &"ActionPaste", &"paste",ITEM_PASTE)
	if options & ITEM_PASTE_AS_SIBLING:
		create_item("Paste as Sibling", &"ActionPaste", &"paste_as_sibling",ITEM_PASTE_AS_SIBLING)
	if item_count and not is_item_separator(item_count - 1):
			add_separator("")
	if options & ITEM_RENAME:
		create_item("Rename", &"Rename", &"rename",ITEM_RENAME)
	if options & ITEM_CHANGE_TYPE:
		create_item("Change Type...", &"RotateLeft", &"change_type",ITEM_CHANGE_TYPE)
	
	if options & ITEM_MOVE_UP:
		create_item("Move Up", &"MoveUp", &"change_type",ITEM_MOVE_UP)
	if options & ITEM_MOVE_DOWN:
		create_item("Move Down", &"MoveDown", &"change_type",ITEM_MOVE_DOWN)
	if options & ITEM_DUPLICATE:
		create_item("Duplicate", &"Duplicate", &"duplicate",ITEM_DUPLICATE)
	if options & ITEM_REPARENT:
		create_item("Reparent...", &"Reparent", &"reparent",ITEM_REPARENT)
	
	if options & ITEM_SAVE_AS_ROOT:
		if item_count and not is_item_separator(item_count - 1):
			add_separator("")
		create_item("Save As Root...", &"NewRoot", &"save_as_root", ITEM_SAVE_AS_ROOT)
	
	if options & ITEM_SHOW_IN_EDITOR:
		if item_count and not is_item_separator(item_count - 1):
			add_separator("")
		create_item("Show in Editor", &"ShowInFileSystem", &"show_in_file_system", ITEM_SHOW_IN_EDITOR)
	
	if options & ITEM_DOCUMENTATION:
		if item_count and not is_item_separator(item_count - 1):
			add_separator("")
		create_item("Open Documentation", &"Help", &"",ITEM_DOCUMENTATION)
	if options & ITEM_DELETE:
		if item_count and not is_item_separator(item_count - 1):
			add_separator("")
		create_item("Delete", &"Remove", &"delete",ITEM_DELETE)
	
	if is_item_separator(item_count - 1):
		remove_item(item_count - 1)


func _on_index_pressed(index: int) -> void:
	pass
	#var event: InputEventShortcut = InputEventShortcut.new()
	#event.shortcut = get_item_shortcut(index)
	#print("Triggering shortcut: %s" % event.shortcut.get_as_text())
	#Input.parse_input_event(event)


const FLAG_LOOKUP: Dictionary = {
	 0 : "ITEM_NONE",
	 1 : "ITEM_ADD_CHILD", 
	 2 : "ITEM_CUT", 
	 4 : "ITEM_COPY", 
	 8 : "ITEM_PASTE", 
	 16 : "ITEM_DUPLICATE", 
	 32 : "ITEM_RENAME", 
	 64 : "ITEM_CHANGE_TYPE", 
	 128 : "ITEM_SAVE_AS_ROOT", 
	 256 : "ITEM_DOCUMENTATION", 
	 512 : "ITEM_DELETE",
	 1024 : "ITEM_ADD_NODE_HERE",
	 2048 : "ITEM_INSTANTIATE_NODE_HERE",
	 4096 : "ITEM_INSTANTIATE_NODE",
	 8192 : "ITEM_PASTE_HERE",
	 16384 : "ITEM_PASTE_AS_SIBLING",
	 32768 : "ITEM_MOVE_UP",
	 65536 : "ITEM_MOVE_DOWN",
	 131072 : "ITEM_REPARENT",
	 262144 : "ITEM_MOVE_NODE_HERE",
	 886 : "ITEMS_DEFAULT",
	 2147483648 : "ITEMS_ALL",
}

func print_option_flags(flags: int) -> void:
	for i: int in FLAG_LOOKUP:
		print("%s(%s) => %s" % [FLAG_LOOKUP[i], i, i & flags])
