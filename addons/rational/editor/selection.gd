@tool
extends RefCounted
## Manages selected items for Rational editor.

## Use this class to get around 
class TreeSelection extends RefCounted:
	var selection: Array[RationalComponent]

## NOTE: This is always emitted deferred.
signal selection_changed

var _changed_signal_queued: bool = false
var _data: Dictionary[RootData, TreeSelection]

var cache: RefCounted

func _init() -> void:
	_init_selection.call_deferred()

func _init_selection() -> void:
	cache = Engine.get_singleton(&"Rational").cache
	cache.data_erased.connect(_on_data_erased)

func add_component(component: RationalComponent) -> void:
	if not component or is_selected(component): return
	get_selected_components().push_back(component)
	emit_changed()

func remove_component(component: RationalComponent) -> void:
	if not component or not is_selected(component): return
	get_selected_components().erase(component)
	emit_changed()

func clear() -> void:
	if get_selected_components().is_empty(): return
	get_selected_components().clear()
	emit_changed()

func is_selected(component: RationalComponent) -> bool:
	return component in get_selected_components()

func get_selected_components() -> Array[RationalComponent]:
	if not _get_key() in _data:
		_data[_get_key()] = TreeSelection.new()
	return _data[_get_key()].selection

## Returns only parents. No children.
func get_top_selected_components() -> Array[RationalComponent]:
	var components: Array[RationalComponent] = get_selected_components().duplicate()
	var i: int = components.size()
	while 0 < i:
		i -= 1
		for c: RationalComponent in components:
			if not c.has_child(components[i], true): continue
			components.remove_at(i)
			break
	return components

func emit_changed() -> void:
	if _changed_signal_queued: return
	_changed_signal_queued = true
	_update.call_deferred()

func _update() -> void:
	selection_changed.emit()
	_changed_signal_queued = false

func _get_key() -> RootData:
	return cache.get_edited_tree()

func _on_data_erased(tree: RootData) -> void:
	_data.erase(tree)
