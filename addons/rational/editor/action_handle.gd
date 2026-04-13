@tool
extends RefCounted

const DEBUG: bool = false

## Emitted when requesting to select/focus GraphNode.
signal request_show_in_editor(comp: RationalComponent)

## Emitted when requesting to delete a component entirely.
signal remove_component(comp: RationalComponent)

## Emitted when adding a component outside of edited tree.
signal add_component(comp: RationalComponent)

var cache: RefCounted
var selection: RefCounted

var undo_redo: EditorUndoRedoManager = EditorInterface.get_editor_undo_redo()

var clipboard: Array[RationalComponent]: set = set_clipboard

var current_edited_object: RootData: set = set_current_edited_object

func _init() -> void:
	init_action_handle.call_deferred()

func init_action_handle() -> void:
	if not Engine.has_singleton(&"Rational"): return
	undo_redo.version_changed.connect(_on_version_changed)
	selection = Engine.get_singleton(&"Rational").selection
	cache = Engine.get_singleton(&"Rational").cache
	cache.edited_tree_changed.connect(set_current_edited_object)
	set_current_edited_object(cache.edited_tree)

func open_documentation(comp: RationalComponent) -> void:
	if not comp: return
	EditorInterface.get_script_editor().goto_help("class_name:%s" % Engine.get_singleton(&"Rational").class_data.comp_get_class(comp))

func move_child_component(parent: RationalComponent, child: RationalComponent, to_idx: int,
			merge_mode: UndoRedo.MergeMode = UndoRedo.MERGE_ALL, execute: bool = true) -> void:
	move_child(parent, parent.get_child_index(child), to_idx, merge_mode, execute)

## Call with null parent to start action.
func move_child(parent: RationalComponent, from_idx: int, to_idx: int,
			merge_mode: UndoRedo.MergeMode = UndoRedo.MERGE_ALL, execute: bool = true) -> void:
	create_action("Move Component(s) in Parent", merge_mode, )
	if parent:
		var child: RationalComponent = parent.get_child(from_idx)
		undo_redo.add_undo_method(parent, "move_child", child, from_idx)
		undo_redo.add_do_method(parent, "move_child", child, to_idx)
	commit(execute)

## Only changes [param comp] parent. Can be used with only one of [param target_parent] or [param current_parent].
func reparent_item(comp: RationalComponent, target_parent: RationalComponent = null, current_parent: RationalComponent = null, 
			merge_mode: UndoRedo.MergeMode = UndoRedo.MERGE_ALL, execute: bool = true) -> void:	
	
	if not comp or (not target_parent and not current_parent):
		push_warning("Cannot Reparent. Component missing or both parent components missing.")
		return
	
	create_action("Reparent Component(s)", merge_mode, )
	if target_parent:
		undo_redo.add_undo_method(target_parent, &"remove_child", comp)
	
	if current_parent:
		undo_redo.add_undo_method(current_parent, &"add_child", comp)
		undo_redo.add_do_method(current_parent, &"remove_child", comp)
	
	if target_parent:
		undo_redo.add_do_method(target_parent, &"add_child", comp)
	
	commit(execute)

func prompt_add_child(parent: RationalComponent) -> void:
	if not parent is Composite: return
	EditorInterface.popup_create_dialog(add_new_child.bind(parent), &"RationalComponent", "", "Add Child Component", [])

func prompt_instantiate_child(parent: RationalComponent) -> void:
	if not parent is Composite: return
	# TODO

func add_new_child(path: String, parent: RationalComponent) -> void:
	if not path: return
	add_child(parent, _instantiate_component_from_path(path))

func add_child(parent: RationalComponent, child: RationalComponent, 
			merge_mode: UndoRedo.MergeMode = UndoRedo.MERGE_ALL, execute: bool = true) -> void:
	if not parent or not child or not parent.can_parent(child): return
	create_action("Add Child Component", merge_mode, )
	undo_redo.add_undo_method(parent, &"remove_child", child)
	emit_remove(child)
	undo_redo.add_do_method(parent, &"add_child", child)
	commit(execute)

## Only removes child from parent. Will not delete corresponding GraphNode.
#func remove_child(parent: RationalComponent, child: RationalComponent, 
			#merge_mode: UndoRedo.MergeMode = UndoRedo.MERGE_ALL, execute: bool = true) -> void:
	#if not parent or not parent.has_child(child): return
	#create_action("Unparent Component", merge_mode, )
	#undo_redo.add_do_method(parent, &"add_child", child)
	#undo_redo.add_undo_method(parent, &"remove_child", child)
	#commit(execute)

func paste(parent: RationalComponent, merge_mode: UndoRedo.MergeMode = UndoRedo.MERGE_ALL, execute: bool = true) -> void:
	if not parent is Composite or not can_paste(): return
	
	create_action("Paste Component(s) as child of %s" % parent.get_name(), merge_mode, )
	for child: RationalComponent in get_top_clipboard_components().duplicate_deep(Resource.DEEP_DUPLICATE_INTERNAL):
		if not parent.can_parent(child): continue
		undo_redo.add_undo_method(parent, &"remove_child", child)
		emit_remove(child)
		undo_redo.add_do_method(parent, &"add_child", child)
	
	commit(execute)

func paste_as_sibling(parent: RationalComponent, sibling: RationalComponent, 
			merge_mode: UndoRedo.MergeMode = UndoRedo.MERGE_ALL, execute: bool = true) -> void:
	create_action("Paste Component(s) as sibling of %s" % sibling.get_name(), merge_mode, )
	if not parent or not sibling: return
	
	for child: RationalComponent in get_top_clipboard_components().duplicate_deep(Resource.DEEP_DUPLICATE_INTERNAL):
		if not parent.can_parent(child): continue
		undo_redo.add_undo_method(parent, &"remove_child", child)
		emit_remove(child)
		undo_redo.add_do_method(parent, &"add_child", child)
	
	commit(execute)

## Only prompts to change type. 
func change_type(comp: RationalComponent) -> void:
	if not comp: return
	EditorInterface.popup_create_dialog(change_script.bind(comp), &"RationalComponent", "", 
			"Change Component Type", [])

func change_script(path: String, comp: RationalComponent) -> void:
	if not path: return
	create_action("Change Component(s) Type", UndoRedo.MERGE_ALL, )
	undo_redo.add_undo_method(comp, &"set_script", comp.get_script())
	undo_redo.add_do_method(comp, &"set_script", ResourceLoader.load(path, "Script"))
	commit()

func rename(comp: RationalComponent, to_name: String) -> void:
	if comp.resource_name == to_name: return
	create_action("Rename Component", UndoRedo.MERGE_DISABLE, )
	undo_redo.add_do_property(comp, &"resource_name", to_name)
	undo_redo.add_undo_property(comp, &"resource_name", comp.resource_name)
	commit()

func delete() -> void:
	if not get_edited_tree_root() or get_selected_components().is_empty(): return
	var root: RationalComponent = get_edited_tree_root()
	for comp: RationalComponent in get_selected_components():
		create_action("Remove Component(s)")
		undo_redo_remove(comp, root.find_parent(comp))
		commit()

func cut() -> void:
	copy()
	if not get_edited_tree_root() or get_selected_components().is_empty(): return
	print("Cutting")
	var root: RationalComponent = get_edited_tree_root()
	for comp: RationalComponent in get_top_selected_filtered():
		print("Cutting Comp: %s" % comp)
		create_action("Cut Component(s)")
		undo_redo_remove(comp, root.find_parent(comp))
		commit()


func copy() -> void:
	set_clipboard(selection.get_selected_components().duplicate())

func duplicate() -> void:
	if not get_edited_tree_root(): return
	
	var selected:= get_selected_components()
	var root: RationalComponent = get_edited_tree_root()
	
	for comp: RationalComponent in get_top_selected_components():
		var new_comp: RationalComponent = filter_unselected(comp, comp.duplicate_deep(Resource.DEEP_DUPLICATE_INTERNAL), selected)
		create_action("Duplicate Component(s)")
		undo_redo_add(new_comp, root.find_parent(comp))
		
		commit()

## Adds [member undo_redo] methods for adding a new component to the editor.
func undo_redo_add(comp: RationalComponent, parent: RationalComponent = null, ) -> void:
	emit_add(comp)
	
	undo_redo.add_undo_method(selection, &"remove_component", comp)
	
	if parent:
		undo_redo.add_undo_method(parent, &"remove_child", comp)
		undo_redo.add_do_method(parent, &"add_child", comp)
	
	undo_redo.add_do_method(selection, &"add_component", comp)


## Adds [member undo_redo] methods for removing a component from the tree entirely.
func undo_redo_remove(comp: RationalComponent, parent: RationalComponent = null) -> void:
	emit_remove(comp)
	
	undo_redo.add_undo_method(selection, &"add_component", comp)
	
	if parent:
		undo_redo.add_undo_method(parent, &"add_child", comp)
	
	undo_redo.add_do_method(selection, &"remove_component", comp)
	
	if parent:
		undo_redo.add_do_method(parent, &"remove_child", comp)


func get_edited_tree_root() -> RationalComponent:
	return cache.get_edited_comp()

func is_component_selected(comp: RationalComponent) -> void:
	return selection.is_selected(comp)

func get_selected_components() -> Array[RationalComponent]:
	return selection.get_selected_components().duplicate()

## Array already duplicated (but not the resources themselves).
func get_top_selected_components() -> Array[RationalComponent]:
	return selection.get_top_selected_components()

func filter_unselected(original: RationalComponent, comp: RationalComponent, selected: Array[RationalComponent] = get_selected_components()) -> RationalComponent:
	assert(original.get_child_count() == comp.get_child_count())
	var i: int = original.get_child_count()
	while 0 < i:
		i -= 1
		if original.get_child(i) in selected:
			filter_unselected(original.get_child(i), comp.get_child(i), selected)
		else:
			comp.remove_index(i)
	return comp

func get_top_selected_filtered(duplicate_mode: Resource.DeepDuplicateMode = Resource.DEEP_DUPLICATE_INTERNAL) -> Array[RationalComponent]:
	var result: Array[RationalComponent]
	for comp: RationalComponent in get_top_selected_components():
		result.push_back(filter_unselected(comp, comp.duplicate_deep(duplicate_mode), get_selected_components()))
	return result

## Components are not duplicated.
func get_top_clipboard_components() -> Array[RationalComponent]:
	var components: Array[RationalComponent] = get_clipboard().duplicate()
	var i: int = components.size()
	while 0 < i:
		i -= 1
		for c: RationalComponent in components:
			if not c.has_child(components[i], true): continue
			components.remove_at(i)
			break
	return components


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

## Emits signal for GraphEdit to add this component as an orphan.
func emit_add(comp: RationalComponent) -> void:
	add_component.emit(comp)

## Emits signal for GraphEdit to add_methods to remove this component entirely.
func emit_remove(comp: RationalComponent) -> void:
	remove_component.emit(comp)

## Internal Use.
func _instantiate_component_from_path(path: String) -> RationalComponent:
	var script: GDScript = ResourceLoader.load(path, "GDScript")
	var comp: RationalComponent = script.new()
	comp.set_name(script.get_global_name())
	return comp


func _on_version_changed() -> void:
	var ur:= get_history()
	#if undo_redo.get_object_history_id()

func swap_to_data(data: RootData) -> void:
	cache.edit_tree(data)

func _on_closed(data: RootData) -> void:
	if data.is_builtin():
		clear_history()

#region UndoRedo Wrappers

func create_action(name: String, merge_mode: UndoRedo.MergeMode = UndoRedo.MERGE_ALL,
			backward_undo_ops: bool = false, mark_unsaved: bool = false) -> void:
	
	if current_edited_object and not current_edited_object.closed.is_connected(_on_closed):
		current_edited_object.closed.connect(_on_closed, CONNECT_APPEND_SOURCE_OBJECT)
	
	undo_redo.create_action(name, merge_mode, null, backward_undo_ops, mark_unsaved)
	
	undo_redo.add_undo_method(self, &"swap_to_data", current_edited_object)
	undo_redo.add_do_method(self, &"swap_to_data", current_edited_object)
	
	if DEBUG:
		print("Created action: '%s' | Merge: %s | Backwards: %s | Mark Unsaved: %s" % [name, "ALL" if merge_mode else "DISABLE", backward_undo_ops, mark_unsaved])

func commit(execute: bool = true) -> void:
	undo_redo.commit_action(execute)
	if DEBUG:
		var ur:= get_history()
		print("Commited action #%2d - %s" % [ur.get_current_action(), ur.get_current_action_name()])

func get_history() -> UndoRedo:
	return undo_redo.get_history_undo_redo(EditorUndoRedoManager.GLOBAL_HISTORY)

func clear_history() -> void:
	undo_redo.clear_history(EditorUndoRedoManager.GLOBAL_HISTORY)

#endregion UndoRedo Wrappers

func has_selection() -> bool:
	return not selection.get_selected_components().is_empty()

func can_paste() -> bool:
	return has_clipboard()

func clear_clipboard() -> void:
	clipboard.clear()

func has_clipboard() -> bool:
	return not clipboard.is_empty()

## [param top_components] will filter out any child components in the clipboard.
func get_clipboard(top_components: bool = false) -> Array[RationalComponent]:
	return filter_child_components(clipboard, Resource.DEEP_DUPLICATE_NONE) if top_components else clipboard

func set_clipboard(value: Array[RationalComponent]) -> void:
	clipboard.assign(value)

func get_undo_redo() -> Object:
	return undo_redo

func set_current_edited_object(obj: RootData) -> void:
	current_edited_object = obj
