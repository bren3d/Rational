@tool
extends RefCounted

#var undo_redo_map: Dictionary[RootData]

var undo_redo: EditorUndoRedoManager = EditorInterface.get_editor_undo_redo()

var clipboard: Array[RationalComponent]: set = set_clipboard

# To track if history should be cleared.
var last_edited_object: Object
var current_edited_object: Object: set = set_current_edited_object

var block_action_commits: bool = false

func _init() -> void:
	if not Engine.has_singleton(&"Rational"): return
	Engine.get_singleton(&"Rational").cache.edited_tree_changed.connect(set_current_edited_object)

func save_as_root() -> void:
	pass

func move_child_component(parent: RationalComponent, child: RationalComponent, to_idx: int,
			merge_mode: UndoRedo.MergeMode = UndoRedo.MERGE_DISABLE, execute: bool = true) -> void:
	move_child(parent, parent.get_child_index(child), to_idx, merge_mode, execute)

## Call with null parent to start action.
func move_child(parent: RationalComponent, from_idx: int, to_idx: int,
			merge_mode: UndoRedo.MergeMode = UndoRedo.MERGE_DISABLE, execute: bool = true) -> void:
	create_action("Move Component(s) in Parent", merge_mode, )
	if parent:
		var child: RationalComponent = parent.get_child(from_idx)
		undo_redo.add_undo_method(parent, "move_child", child, from_idx)
		undo_redo.add_do_method(parent, "move_child", child, to_idx)
	commit(execute)
	

func reparent_item(comp: RationalComponent, target_parent: RationalComponent, current_parent: RationalComponent, 
			merge_mode: UndoRedo.MergeMode = UndoRedo.MERGE_DISABLE, execute: bool = true) -> void:	
	
	create_action("Reparent Component(s)", merge_mode, )
	if comp: 
		undo_redo.add_undo_method(target_parent, &"remove_child", comp)
		undo_redo.add_undo_method(current_parent, &"add_child", comp)
		
		undo_redo.add_do_method(current_parent, &"remove_child", comp)
		undo_redo.add_do_method(target_parent, &"add_child", comp)
	
	commit(execute)

func prompt_add_child(parent: RationalComponent) -> void:
	EditorInterface.popup_create_dialog(add_new_child.bind(parent), &"RationalComponent", "", "Add Child Component", [])

func add_new_child(path: String, parent: RationalComponent) -> void:
	if not path: return
	add_child(parent, instantiate_comp(path))

func add_child(parent: RationalComponent, child: RationalComponent, 
			merge_mode: UndoRedo.MergeMode = UndoRedo.MERGE_DISABLE, execute: bool = true) -> void:
	if (parent and not parent.can_parent(child)) : return
	create_action("Add Component", merge_mode, )
	if not parent: return
	
	if child:
		undo_redo.add_do_method(parent, &"add_child", child)
		undo_redo.add_undo_method(parent, &"remove_child", child)
	commit(execute)


func paste(parent: RationalComponent, merge_mode: UndoRedo.MergeMode = UndoRedo.MERGE_DISABLE, execute: bool = true) -> void:
	if not parent is Composite or not has_clipboard(): return
	
	var comps: Array[RationalComponent] = filter_child_components(clipboard, Resource.DEEP_DUPLICATE_ALL)
	create_action("Paste Component(s) as child of %s" % parent.get_name(), merge_mode, )
	for child: RationalComponent in comps:
		if not parent.can_parent(child): continue
		undo_redo.add_undo_method(parent, &"remove_child", child)
		undo_redo.add_do_method(parent, &"add_child", child)
	
	commit(execute)

func paste_as_sibling(parent: RationalComponent, sibling: RationalComponent, 
			merge_mode: UndoRedo.MergeMode = UndoRedo.MERGE_DISABLE, execute: bool = true) -> void:
	var comps: Array[RationalComponent] = filter_child_components(clipboard, Resource.DEEP_DUPLICATE_ALL)
	create_action("Paste Component(s) as sibling of %s" % sibling.get_name(), merge_mode, )
	for child: RationalComponent in comps:
		if not parent.can_parent(child): continue
		undo_redo.add_undo_method(parent, &"remove_child", child)
		undo_redo.add_do_method(parent, &"add_child", child)
	
	commit(execute)

func delete(parent: RationalComponent, child: RationalComponent, 
			merge_mode: UndoRedo.MergeMode = UndoRedo.MERGE_DISABLE, execute: bool = true) -> void:
	create_action("Remove Component(s)", merge_mode, )
	if not parent: return
	undo_redo.add_undo_method(parent, &"add_child", child, parent.get_child_index(child))
	undo_redo.add_do_method(parent, &"remove_child", child)
	commit()

func delete_node(node: Node, merge_mode: UndoRedo.MergeMode = UndoRedo.MERGE_DISABLE, execute: bool = true) -> void:
	create_action("Remove Component(s)", merge_mode, )
	
	undo_redo.add_undo_method(node.get_parent(), &"add_child", node)
	undo_redo.add_undo_reference(node)
	
	undo_redo.add_do_method(node.get_parent(), &"remove_child", node)
	
	commit(execute)

func change_type(comp: RationalComponent) -> void:
	if not comp: return
	EditorInterface.popup_create_dialog(change_script.bind(comp), &"RationalComponent", "", 
			"Change Component Type", [])

func change_script(path: String, comp: RationalComponent) -> void:
	if not path: return
	
	create_action("Change Component(s) Type", UndoRedo.MERGE_DISABLE, )
	undo_redo.add_undo_method(comp, &"set_script", comp.get_script())
	undo_redo.add_do_method(comp, &"set_script", ResourceLoader.load(path, "Script"))
	commit()

func rename(comp: RationalComponent, to_name: String) -> void:
	create_action("Rename Component", UndoRedo.MERGE_DISABLE, )
	undo_redo.add_do_property(comp, &"resource_name", to_name)
	undo_redo.add_undo_property(comp, &"resource_name", comp.resource_name)
	commit()


func cut(items: Array[RationalComponent]) -> void:
	if not items: return
	copy(items)
	#create_action("Cut Component(s)")
	##undo_redo.add_do_property(comp, &"resource_name", to_name)
	##undo_redo.add_undo_property(comp, &"resource_name", comp.resource_name)
	#commit()

func cut_node(node: Node, merge_mode: UndoRedo.MergeMode = UndoRedo.MERGE_DISABLE, execute: bool = true, ) -> void:
	create_action("Cut Component(s)", merge_mode, )
	delete_node(node, merge_mode, )

func copy(items: Array[RationalComponent]) -> void:
	set_clipboard(items)

## Filters [param components] to remove those that are children of others in [param components].
func filter_child_components(input_components: Array[RationalComponent], duplicate_mode: int = Resource.DEEP_DUPLICATE_ALL) -> Array[RationalComponent]:
	var components: Array[RationalComponent] = input_components.duplicate_deep(duplicate_mode)
	var i: int = components.size()
	while 0 < i:
		i -= 1
		for c: RationalComponent in components:
			if not c.has_child(components[i], true): continue
			components.remove_at(i)
			break
	return components

func instantiate_comp(path: String) -> RationalComponent:
	var script: GDScript = ResourceLoader.load(path, "GDScript")
	var comp: RationalComponent = script.new()
	comp.set_name(script.get_global_name())
	return comp

func update_edited_object() -> void:
	if current_edited_object == last_edited_object: return
	clear_history()
	last_edited_object = current_edited_object

#region UndoRedo Wrappers

func create_action(name: String, merge_mode: UndoRedo.MergeMode = UndoRedo.MERGE_DISABLE,
			backward_undo_ops: bool = false, mark_unsaved: bool = true) -> void:
	if block_action_commits: return
	update_edited_object()
	undo_redo.create_action(name, merge_mode, self, backward_undo_ops, mark_unsaved)

func commit(execute: bool = true) -> void:
	if block_action_commits: return
	undo_redo.commit_action(execute)

func clear_history() -> void:
	undo_redo.clear_history(EditorUndoRedoManager.GLOBAL_HISTORY,)

#endregion UndoRedo Wrappers


func can_paste() -> bool:
	return has_clipboard()

func clear_clipboard() -> void:
	clipboard.clear()

func has_clipboard() -> bool:
	return not clipboard.is_empty()

## [param top_components] will filter out any child components in the clipboard.
func get_clipboard(top_components: bool = false, duplicate_mode: int = Resource.DEEP_DUPLICATE_ALL) -> Array[RationalComponent]:
	return filter_child_components(clipboard) if top_components else clipboard

func set_clipboard(value: Array[RationalComponent]) -> void:
	clipboard.assign(value)

func get_undo_redo() -> Object:
	return undo_redo

func set_current_edited_object(obj: Object) -> void:
	current_edited_object = obj
