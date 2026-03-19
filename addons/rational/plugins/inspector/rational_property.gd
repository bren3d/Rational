@tool
extends EditorResourcePicker

const Util := preload("res://addons/rational/util.gd")

func _init(base_type: String = "RationalComponent") -> void:
	self.base_type = base_type


func _handle_menu_selected(idx: int) -> bool:

	return false


func _set_create_options(menu_node: Object) -> void:
	var menu: PopupMenu = menu_node

	var item: int = 0
	menu_node.remove_item(item)
	item += 1


	const MENU_ITEMS: PackedStringArray = ["Composite", "Leaf", "Decorator"]
	var class_list: Array[Dictionary] = ProjectSettings.get_global_class_list().filter(func(x: Dictionary)->bool: return x.name in ["Composite", "Leaf", "Decorator", "RationalComponent", "RationalTree"] )
	for dict: Dictionary in class_list:
		(dict.path)
	var bases: Dictionary
	
	for menu_name: String in MENU_ITEMS:
		bases[menu_name] = []
		var inhereting_classes: PackedStringArray = []
		for dict: Dictionary in class_list:
			bases[dict.name] = dict.base


	var subs: Dictionary={"Composite" = [], "Leaf" = [], "Decorator" = [],}

	for cname: String in bases.keys():

		var base_name: String = bases[cname]
		while base_name:
			match base_name:
				"Decorator": 
					subs["Decorator"].append(cname)
				"Composite": 
					subs["Composite"].append(cname)
				"Leaf": 
					subs["Leaf"].append(cname)
				_: 
					base_name = bases.get(base_name, "")
					continue
			break



	for base_class: String in ["Composite", "Leaf", "Decorator"]:
		var sub: Dictionary = {
			base_class = base_class,
			#icon = Util.class_get_icon(base_class),
			subitems = [], }
		
	# for i: int in menu.item_count:
	# 	var item_name: String = menu.get_item_text(i)
		# if item_name not in ["Component", "Leaf", "Composite"]: pass

	var create_submenu: Callable = \
		func(items: Array[Dictionary]) -> PopupMenu:
			var submenu: PopupMenu = PopupMenu.new()
			for i: int in items.size(): submenu.add_icon_item(items[i].icon, items[i].text)
			return submenu

	# menu.set_item_submenu_node(


func _set(property: StringName, value: Variant) -> bool:
	
	match property:
		
		&"edited_resource":
			edited_resource = value
			resource_changed.emit.call_deferred(value)

		
	return false
