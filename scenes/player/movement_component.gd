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


## Frena rapido al perforar: el player queda clavado hasta destruir el ore.
func stop(entity: CharacterBody2D, delta: float) -> void:
	entity.velocity = entity.velocity.lerp(Vector2.ZERO, acceleration * delta * 4.0)
	if entity.velocity.length() < stop_threshold:
		entity.velocity = Vector2.ZERO
	entity.move_and_slide()


## Solo mata velocity. No llama move_and_slide (evita nudge/flicker por doble slide).
func clear_velocity(entity: CharacterBody2D) -> void:
	entity.velocity = Vector2.ZERO


## Frena y resuelve un slide (usar como unico move del frame mientras perforas).
func hard_stop(entity: CharacterBody2D) -> void:
	entity.velocity = Vector2.ZERO
	entity.move_and_slide()
