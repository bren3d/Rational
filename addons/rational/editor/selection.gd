@tool
extends RefCounted
## Manages selected items for the Rational editor.

## NOTE: This is always emitted deferred.
signal selection_changed

var cache: RefCounted
var _changed_signal_queued: bool = false
var _data: Dictionary[RootData, Array]

func _init() -> void:
	_init_selection.call_deferred()

func _init_selection() -> void:
	cache = Engine.get_singleton(&"Rational").cache
	cache.data_erased.connect(_on_data_erased)

func add_component(component: RationalComponent) -> void:
	if not component or is_selected(component): return
	_get_selected().push_back(component)
	emit_changed()

func remove_component(component: RationalComponent) -> void:
	if not component or not is_selected(component): return
	_get_selected().erase(component)
	emit_changed()

func clear() -> void:
	if _get_selected().is_empty(): return
	_get_selected().clear()
	emit_changed()

func is_selected(component: RationalComponent) -> bool:
	return component in _get_selected()

func set_selected(components: Array[RationalComponent]) -> void:
	_get_selected().assign(components)
	emit_changed()

func _get_selected() -> Array[RationalComponent]:
	if not _get_key() in _data:
		var arr: Array[RationalComponent]
		_data[_get_key()] = arr
	return _data[_get_key()]

## Edits cannot be made directly to the array.
func get_selected_components() -> Array[RationalComponent]:
	return _get_selected().duplicate()

## Returns only parents—No children.
func get_top_selected_components() -> Array[RationalComponent]:
	var components: Array[RationalComponent] = get_selected_components()
	var i: int = components.size()
	while 0 < i:
		i -= 1
		for c: RationalComponent in components:
			if not c.has_child(components[i], true): continue
			components.remove_at(i)
			break
	return components

## Queues [member selection_changed] to be emitted on the next frame. Multiple calls to this are safe.
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
