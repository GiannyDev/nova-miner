extends CharacterBody2D
class_name MinerBody
## Body + drill compartido: oneshot al paso, frena si el bloque sobrevive.
## Contrato de escena: $MovementComponent y %DrillBase. No posee input ni look.

@onready var movement_component: MovementComponent = $MovementComponent
@onready var drill_weapon: DrillWeapon = %DrillBase

@export var face_speed_threshold: float = 20.0

var move_intent: Vector2 = Vector2.ZERO
var facing_direction: Vector2 = Vector2.RIGHT
var aim_direction: Vector2 = Vector2.RIGHT


## Apunta el drill, pega contactos vivos y mueve. Subclases pasan speed/damage.
func tick_miner(delta: float, speed: float, damage: float) -> void:
	update_facing_from_intent()
	aim_direction = get_drill_aim_direction()
	drill_weapon.set_aim_direction(aim_direction)
	drill_weapon.tick(damage, delta, has_move_intent())
	if should_stop_for_drill():
		velocity = Vector2.ZERO
		move_and_slide()
		return
	movement_component.move(self, move_intent, delta, speed)


## Solo movimiento / ultimo facing. Nunca apunta a un ore concreto.
func get_drill_aim_direction() -> Vector2:
	if has_move_intent():
		return move_intent.normalized()
	if facing_direction.length_squared() > 0.01:
		return facing_direction.normalized()
	return Vector2.RIGHT


func update_facing_from_intent() -> void:
	if has_move_intent():
		facing_direction = move_intent.normalized()
	elif velocity.length_squared() > face_speed_threshold * face_speed_threshold:
		facing_direction = velocity.normalized()


func has_move_intent() -> bool:
	return move_intent.length_squared() > 0.01


## True si hay un bloque vivo en el tip que no muere de un golpe.
func should_stop_for_drill() -> bool:
	return drill_weapon.is_drilling()
