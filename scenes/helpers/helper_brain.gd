extends Node
class_name HelperBrain
## Solo vaga: heading aleatorio a intervalos. No elige bloques.

var helper: Helper
var turn_timer: float = 0.0


func setup(owner_helper: Helper) -> void:
	helper = owner_helper


func tick(delta: float) -> void:
	if helper.should_stop_for_drill():
		return
	turn_timer -= delta
	if turn_timer <= 0.0:
		pick_heading()


## Nueva direccion al azar. Mientras perfora un bloque duro, no gira (empuja como el player).
func pick_heading() -> void:
	helper.move_intent = Vector2.from_angle(randf() * TAU)
	turn_timer = randf_range(get_heading_seconds_min(), get_heading_seconds_max())


func get_heading_seconds_min() -> float:
	return helper.data.heading_seconds_min if helper.data != null else 0.45


func get_heading_seconds_max() -> float:
	var max_seconds := helper.data.heading_seconds_max if helper.data != null else 1.35
	return maxf(max_seconds, get_heading_seconds_min())
