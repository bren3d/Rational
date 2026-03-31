## A type of [Composite] that changes the response received from a single child.
@abstract
@tool
class_name Decorator extends Composite


@abstract func _no_tick(delta: float, board: Blackboard, actor: Node) -> int

@abstract func _tick(delta: float, board: Blackboard, actor: Node) -> int


func add_child(child: RationalComponent, idx: int = -1) -> void:
	if not can_parent(child): return
	if not children.is_empty() and children[0]:
		children[0].tree_changed.disconnect(notify_tree_changed)
	children.clear()
	super(child)

func remove_child(child: RationalComponent) -> void:
	if not child or not has_child(child):
		return
	child.tree_changed.disconnect(notify_tree_changed)
	children.clear()
	children_changed.emit()
	notify_tree_changed()

## Do nothing because there should only be one child.
func move_child(child: RationalComponent, to_index: int = -1) -> void:
	assert(children.size() < 2, "Decorator should not have more than 1 child.")


func _validate_property(property: Dictionary) -> void:
	if property.name == &"children":
		property.usage &= ~PROPERTY_USAGE_EDITOR
	super(property)


func _get_property_list() -> Array[Dictionary]:
	return [{
				name = &"child",
				type = TYPE_OBJECT,
				hint = PROPERTY_HINT_RESOURCE_TYPE,
				hint_string = &"RationalComponent",
			}] 

func _get(property: StringName) -> Variant:
	return children[0] if property == &"child" and not children.is_empty() else null

func _set(property: StringName, value: Variant) -> bool:
	if property == &"child":
		if value:
			add_child(value)
		else:
			remove_child(get(&"child"))
		notify_property_list_changed()
	
	return super(property, value)
