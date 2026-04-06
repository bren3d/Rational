@tool
extends CharacterBody2D



func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint(): return
	const SPEED:= 300.0
	var direction := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down").normalized()
	
	if direction:
		velocity = direction * SPEED
		
	else:
		velocity = velocity.move_toward(Vector2.ZERO, SPEED)

	move_and_slide()
