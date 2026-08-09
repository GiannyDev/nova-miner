extends Node
## Feedbacks cross-cutting: saltos, flights, damage text y squash reutilizables.

## Hace un salto juice de un objeto desde una posicion a otra con un arco.
func do_jump(node: Node2D, from: Vector2, to: Vector2, duration: float, height: float) -> void:
	var control := Vector2(
		lerpf(from.x, to.x, 0.35),
		minf(from.y, to.y) - height
	)

	var tween: Tween = create_tween()
	tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_method(func(t: float):
		node.global_position = _quadratic_bezier(from, control, to, t), 0.0, 1.0, duration
	)

	await tween.finished


## Vuela un Node2D hacia un target con arco (drops, pickups).
func do_fly_towards_2D_target(node: Node2D, target: Node2D, time: float, height: float = 40.0) -> void:
	await do_jump(node, node.global_position, target.global_position, maxf(time, 0.05), height)


## Spawnea damage text en mundo, viajando en la direccion del minado.
func spawn_damage_text(amount: float, world_pos: Vector2, direction: Vector2) -> void:
	var text: DamageText = Refs.DAMAGE_TEXT_SCENE.instantiate()
	var parent: Node = Refs.player.get_parent()
	parent.add_child(text)
	text.global_position = world_pos
	text.play(amount, direction)


## Vuela un Control hacia otro (UI feedback).
func do_control_fly_towards_target(control: Control, target: Control, time: float, height: float = 24.0) -> void:
	var from := control.global_position
	var to := target.global_position
	var control_point := Vector2(
		lerpf(from.x, to.x, 0.35),
		minf(from.y, to.y) - height
	)

	var tween := create_tween()
	tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_method(func(t: float):
		control.global_position = _quadratic_bezier(from, control_point, to, t), 0.0, 1.0, maxf(time, 0.05)
	)
	await tween.finished


func do_horizontal_squash(node: Node2D, amount: float = 0.15, duration: float = 0.12) -> void:
	var base := node.scale
	var tween := create_tween()
	tween.tween_property(node, "scale", Vector2(base.x * (1.0 + amount), base.y * (1.0 - amount)), duration * 0.4)
	tween.tween_property(node, "scale", base, duration * 0.6).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func do_vertical_squash(node: Node2D, amount: float = 0.15, duration: float = 0.12) -> void:
	var base := node.scale
	var tween := create_tween()
	tween.tween_property(node, "scale", Vector2(base.x * (1.0 - amount), base.y * (1.0 + amount)), duration * 0.4)
	tween.tween_property(node, "scale", base, duration * 0.6).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func do_control_horizontal_squash_to_left(control: Control, amount: float = 0.12, duration: float = 0.12) -> void:
	control.pivot_offset = Vector2(control.size.x, control.size.y * 0.5)
	var base := control.scale
	var tween := create_tween()
	tween.tween_property(control, "scale", Vector2(base.x * (1.0 - amount), base.y * (1.0 + amount)), duration * 0.4)
	tween.tween_property(control, "scale", base, duration * 0.6).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func do_control_horizontal_squash_to_right(control: Control, amount: float = 0.12, duration: float = 0.12) -> void:
	control.pivot_offset = Vector2(0.0, control.size.y * 0.5)
	var base := control.scale
	var tween := create_tween()
	tween.tween_property(control, "scale", Vector2(base.x * (1.0 - amount), base.y * (1.0 + amount)), duration * 0.4)
	tween.tween_property(control, "scale", base, duration * 0.6).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _quadratic_bezier(p0: Vector2, p1: Vector2, p2: Vector2, t: float) -> Vector2:
	var u := 1.0 - t
	return (u * u * p0) + (2.0 * u * t * p1) + (t * t * p2)
