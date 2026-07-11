extends Node
class_name MovementComponent

@export var acceleration: float = 12.0
@export var stop_threshold: float = 4.0

## Aplica movimiento suave con aceleracion y frenado gradual.
func move(entity: CharacterBody2D, direction: Vector2, delta: float, movement_speed: float) -> void:
	var target_velocity := direction * movement_speed
	entity.velocity = entity.velocity.lerp(target_velocity, acceleration * delta)

	if direction == Vector2.ZERO and entity.velocity.length() < stop_threshold:
		entity.velocity = Vector2.ZERO

	entity.move_and_slide()
