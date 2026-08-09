extends Node2D
class_name DamageText
## Numero de dano flotante: pop gordo → estirado, viaja en la direccion del golpe.

@export var spawn_offset: float = 28.0
@export var min_float_distance: float = 14.0
@export var max_float_distance: float = 14.0
@export var fat_scale: Vector2 = Vector2(1.65, 0.62)
@export var stretch_scale: Vector2 = Vector2(0.68, 1.7)
@export var fat_duration: float = 0.09
@export var stretch_duration: float = 0.14
@export var float_duration: float = 0.38
@export var fade_duration: float = 0.16
@export var side_jitter: float = 10.0

@onready var label: Label = $Label

## Arranca la animacion juicy hacia `direction` (direccion de minado).
func play(amount: float, direction: Vector2) -> void:
	var dir := direction.normalized() if direction.length_squared() > 0.0001 else Vector2.UP
	var side := Vector2(-dir.y, dir.x) * randf_range(-side_jitter, side_jitter)
	label.text = str(maxi(int(round(amount)), 1))
	await get_tree().process_frame
	label.pivot_offset = label.size * 0.5

	global_position += dir * spawn_offset + side
	scale = Vector2.ZERO
	modulate.a = 1.0
	var end_pos := global_position + dir * randf_range(min_float_distance, max_float_distance)

	var tween := create_tween()
	tween.set_parallel(false)
	# Pop gordo.
	tween.tween_property(self, "scale", fat_scale, fat_duration).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	# Alargar + empezar a flotar.
	tween.tween_property(self, "scale", stretch_scale, stretch_duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(self, "global_position", end_pos, float_duration).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	# Asentar y fade.
	tween.tween_property(self, "scale", Vector2.ONE, 0.12).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(self, "modulate:a", 0.0, fade_duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	await tween.finished
	queue_free()
