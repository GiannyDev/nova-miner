extends Node2D
class_name OreDrop

@export var cell_spawn_radius: float = 48.0
@export var drop_y_fall_amount: float = 36.0
@export var first_bounce_height: float = 52.0
@export var second_bounce_height: float = 28.0
@export var lateral_bounce_spread: float = 56.0
@export var fall_duration: float = 0.22
@export var bounce_up_duration: float = 0.18
@export var home_duration: float = 0.35
@export var home_arc_height: float = 40.0

var ore_data: OreData
var pickup_amount: int = 1

## Spawnea en el centro de la celda, cae con 2 rebotes y luego va al player.
func setup(spawn_pos: Vector2, data: OreData = null, amount: int = 1) -> void:
	ore_data = data
	pickup_amount = maxi(amount, 1)
	var offset := Vector2(
		randf_range(-cell_spawn_radius, cell_spawn_radius),
		randf_range(-cell_spawn_radius * 0.2, cell_spawn_radius * 0.2)
	)
	global_position = spawn_pos + offset
	scale = Vector2.ZERO

	var pop := create_tween()
	pop.tween_property(self, "scale", Vector2.ONE, 0.1)\
		.set_trans(Tween.TRANS_BACK)\
		.set_ease(Tween.EASE_OUT)

	await play_drop_and_home()


func play_drop_and_home() -> void:
	var floor_y := global_position.y + drop_y_fall_amount
	var direction := -1.0 if randf() < 0.5 else 1.0
	var travel := direction * randf_range(lateral_bounce_spread * 0.7, lateral_bounce_spread)

	## Caida inicial + 2 rebotes con desplazamiento lateral claro.
	await move_to(Vector2(global_position.x + travel * 0.35, floor_y), fall_duration, Tween.EASE_IN)
	await move_to(
		Vector2(global_position.x + travel * 0.25, floor_y - first_bounce_height),
		bounce_up_duration,
		Tween.EASE_OUT
	)
	await move_to(Vector2(global_position.x + travel * 0.25, floor_y), fall_duration * 0.9, Tween.EASE_IN)
	await move_to(
		Vector2(global_position.x + travel * 0.15, floor_y - second_bounce_height),
		bounce_up_duration * 0.85,
		Tween.EASE_OUT
	)
	await move_to(Vector2(global_position.x + travel * 0.1, floor_y), fall_duration * 0.75, Tween.EASE_IN)

	await home_to_player()
	add_ore_to_inventory()
	queue_free()


func move_to(target: Vector2, duration: float, ease_type: Tween.EaseType) -> void:
	var tween := create_tween()
	tween.tween_property(self, "global_position", target, duration)\
		.set_trans(Tween.TRANS_QUAD)\
		.set_ease(ease_type)
	await tween.finished


func home_to_player() -> void:
	var from := global_position
	var to := Refs.player.global_position
	var control := Vector2(
		lerpf(from.x, to.x, 0.4),
		minf(from.y, to.y) - home_arc_height
	)

	var tween := create_tween()
	tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tween.tween_method(
		func(t: float) -> void:
			global_position = quadratic_bezier(from, control, to, t),
		0.0,
		1.0,
		home_duration
	)
	tween.parallel().tween_property(self, "scale", Vector2(0.6, 0.6), home_duration)\
		.set_trans(Tween.TRANS_SINE)\
		.set_ease(Tween.EASE_IN)
	await tween.finished


func quadratic_bezier(p0: Vector2, p1: Vector2, p2: Vector2, t: float) -> Vector2:
	var u := 1.0 - t
	return (u * u * p0) + (2.0 * u * t * p1) + (t * t * p2)


func add_ore_to_inventory() -> void:
	if ore_data == null:
		push_warning("OreDrop: sin OreData, no se agrega al inventario.")
		return
	CurrencyManager.add_ore(ore_data, pickup_amount)
