## A type of [Composite] that changes the response received from a single child.
@abstract
@tool
class_name Decorator extends Composite


@abstract func _no_tick(delta: float, board: Blackboard, actor: Node) -> int

@abstract func _tick(delta: float, board: Blackboard, actor: Node) -> int

func get_class_name() -> Array[StringName]:
	var names: Array[StringName] = super()
	names.push_back(&"Decorator")
	return names


func _validate_property(property: Dictionary) -> void:
	if property.name == &"children":
		property.usage &= ~PROPERTY_USAGE_EDITOR


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
		var childs: Array[RationalComponent]
		childs.push_back(value)
		children = childs
		notify_property_list_changed()
		return true
	
	return super(property, value)
