extends RefCounted
class_name UpgradeTreeJuice
## Reveal estilo ShellDiver: lineas crecen hacia el hijo y al llegar el nodo hace pop.
## El Springer/temblor se aplica solo al terminar la secuencia (no durante).


static func prepare_node_hidden(node: UpgradeNode, rest_position: Vector2, start_rotation_deg: float) -> void:
	UIJuice.prepare_pivot(node)
	node.position = rest_position
	node.scale = Vector2.ZERO
	node.modulate.a = 0.0
	node.self_modulate = Color.WHITE
	node.rotation_degrees = start_rotation_deg
	node.disabled = true


static func animate_line_grow(host: Node, line: UpgradeLine, duration: float, trans: Tween.TransitionType, ease: Tween.EaseType) -> Tween:
	line.grow_progress = 0.0
	line.visible = true
	var tween := host.create_tween()
	tween.tween_property(line, "grow_progress", 1.0, duration).set_trans(trans).set_ease(ease)
	return tween


static func reveal_node(host: Node, node: UpgradeNode, rest_position: Vector2, duration: float, start_rotation_deg: float, flash_peak: float, flash_duration: float) -> Tween:
	UIJuice.prepare_pivot(node)
	node.position = rest_position
	node.scale = Vector2.ZERO
	node.modulate.a = 0.0
	node.self_modulate = Color.WHITE
	node.rotation_degrees = start_rotation_deg

	var tween := host.create_tween()
	tween.set_parallel(true)
	tween.tween_property(node, "scale", Vector2.ONE, duration).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(node, "modulate:a", 1.0, duration * 0.45).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(node, "rotation_degrees", 0.0, duration).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	if flash_peak > 1.0 and flash_duration > 0.0:
		var flash := Color(flash_peak, flash_peak, flash_peak, 1.0)
		node.self_modulate = flash
		tween.tween_property(node, "self_modulate", Color.WHITE, flash_duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

	return tween


## Temblor Springer solo cuando el arbol ya termino de revelarse.
static func apply_finish_spring(node: UpgradeNode, spring_scale: float) -> void:
	if spring_scale <= 0.0:
		return
	UIJuice.prepare_pivot(node)
	node.scale = Vector2.ONE
	Springer.scale(node, spring_scale, 1.0)
