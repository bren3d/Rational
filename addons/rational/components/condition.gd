## [Leaf] that returns SUCCESS or FAILURE depending on
## a single condition. [ConditionLeaf] should never return `RUNNING`.
@tool
@icon("../icons/ConditionLeaf.svg")
class_name ConditionLeaf extends Leaf

## Expression that will return [code]SUCCESS[/code] if true
## and [code]FAILURE[/code] if false. Executes expression using [member RationalTree.actor]
## and a reference to the blackboard as [code]board[/code].
@export_custom(PROPERTY_HINT_EXPRESSION, "") 
var condition: String = "": set = set_condition, get = get_condition

## Expression that is executed on [method RationalComponent.tick] call.
var expression: Expression = Expression.new()

## Represents if the current [member condition] and [member expression] are valid.
var expression_valid: bool = false

func set_condition(value: String) -> void:
	condition = value
	
	# May need to skip/limit in editor.
	expression = Expression.new()
	var error: int = expression.parse(condition, PackedStringArray(["board"]))
	if not Engine.is_editor_hint() and error != OK:
		push_error("Couldn't parse condition `%s`: %s" % [condition, expression.get_error_text()])
	expression_valid = error == OK
	
	changed.emit()

func get_condition() -> String:
	return condition

func _no_tick(delta: float, board: Blackboard, actor: Node) -> int:
	return SUCCESS

func _tick(delta: float, board: Blackboard, actor: Node) -> int:
	if not expression_valid:
		return FAILURE
		
	var result: Variant = expression.execute([board], actor, true)
	
	if expression.has_execute_failed():
		return FAILURE
	
	return SUCCESS if result else FAILURE


#func _get_configuration_warnings() -> PackedStringArray:
	#return PackedStringArray(["Expression invalid"]) if not expression_valid else PackedStringArray()
