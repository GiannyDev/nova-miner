extends RefCounted
class_name UIJuice
## Animaciones UI reutilizables estilo ShellDiver / Forager. Usar desde recap, shops, popups, etc.

static var default_preset: JuicePreset = JuicePreset.new()


static func prepare_pivot(control: Control) -> void:
	if control.pivot_offset.is_zero_approx():
		control.pivot_offset = control.size * 0.5


static func reset_shell_diver(control: Control, rest_position: Vector2, preset: JuicePreset = null) -> void:
	var cfg := resolve_preset(preset)
	prepare_pivot(control)
	control.modulate.a = 0.0
	control.rotation_degrees = cfg.shell_rotation_deg
	control.position = rest_position + Vector2(0.0, cfg.shell_slide_offset)


static func reset_forager(control: Control, rest_position: Vector2) -> void:
	prepare_pivot(control)
	control.position = rest_position
	control.scale = Vector2.ZERO
	control.modulate.a = 0.0


static func animate_shell_diver_in(host: Node, control: Control, rest_position: Vector2, preset: JuicePreset = null) -> Tween:
	var cfg := resolve_preset(preset)
	prepare_pivot(control)
	var tween := host.create_tween()
	tween.set_parallel(true)
	tween.tween_property(control, "modulate:a", 1.0, cfg.shell_fade_duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(control, "position", rest_position, cfg.shell_slide_duration).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	tween.tween_property(control, "rotation_degrees", 0.0, cfg.shell_rotation_duration).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	Springer.rotate(control, cfg.shell_spring_rotate, 0.0)
	return tween


static func animate_forager_pop_in(host: Node, control: Control, rest_position: Vector2, preset: JuicePreset = null) -> Tween:
	var cfg := resolve_preset(preset)
	prepare_pivot(control)
	control.position = rest_position
	control.scale = Vector2.ZERO
	control.modulate.a = 0.0
	var tween := host.create_tween()
	tween.set_parallel(true)
	tween.tween_property(control, "scale", Vector2.ONE, cfg.forager_pop_duration).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(control, "modulate:a", 1.0, cfg.forager_fade_duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	Springer.scale(control, cfg.forager_spring_scale, 1.0)
	return tween


static func animate_fade_in(host: Node, control: CanvasItem, duration: float = 0.25) -> Tween:
	control.modulate.a = 0.0
	var tween := host.create_tween()
	tween.tween_property(control, "modulate:a", 1.0, duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	return tween


## Prepara una fila HUD fuera a la izquierda (usa top_level para no pelear con VBox).
static func prepare_slide_in_from_left(control: Control, rest_global: Vector2, offset: float) -> void:
	control.modulate.a = 0.0
	control.top_level = true
	control.global_position = rest_global + Vector2(-absf(offset), 0.0)


## Slide L→R + fade hacia rest_global. Al terminar, top_level=false para devolver al layout.
static func animate_slide_in_from_left(host: Node, control: Control, rest_global: Vector2, preset: JuicePreset = null) -> Tween:
	var cfg := resolve_preset(preset)
	var tween := host.create_tween()
	tween.set_parallel(true)
	tween.tween_property(control, "modulate:a", 1.0, cfg.slide_in_fade_duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(control, "global_position", rest_global, cfg.slide_in_duration).set_trans(cfg.slide_in_trans).set_ease(cfg.slide_in_ease)
	tween.finished.connect(func() -> void:
		if not is_instance_valid(control):
			return
		control.top_level = false
		control.modulate.a = 1.0
	, CONNECT_ONE_SHOT)
	return tween


static func animate_count_up(host: Node, label: Label, from_value: float, to_value: float, formatter: Callable, preset: JuicePreset = null) -> Tween:
	var cfg := resolve_preset(preset)
	var tween := host.create_tween()
	tween.tween_method(func(value: float) -> void: label.text = formatter.call(value), from_value, to_value, cfg.count_up_duration).set_trans(cfg.count_up_trans).set_ease(cfg.count_up_ease)
	return tween


static func resolve_preset(preset: JuicePreset) -> JuicePreset:
	return preset if preset != null else default_preset
