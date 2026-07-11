extends Node

signal transition_finished

@onready var effect: ColorRect = %Effect

var fade_tween: Tween


func _ready() -> void:
	hide_effect()


func fade_in(time: float, on_finished: Callable = Callable()) -> void:
	effect.show()
	await fade_to(0.0, time)
	hide_effect()
	invoke_finished(on_finished)


func fade_out(time: float, on_finished: Callable = Callable()) -> void:
	effect.show()
	await fade_to(1.0, time)
	invoke_finished(on_finished)


func fade_to(target_progress: float, time: float) -> void:
	var material := get_shader_material()
	if material == null:
		return

	if fade_tween:
		fade_tween.kill()

	var start_progress: float = material.get_shader_parameter("_Progress")
	if time <= 0.0:
		set_progress(target_progress)
		return

	fade_tween = create_tween()
	fade_tween.tween_method(set_progress, start_progress, target_progress, time)\
		.set_trans(Tween.TRANS_QUINT)\
		.set_ease(Tween.EASE_IN_OUT)
	await fade_tween.finished


func set_progress(value: float) -> void:
	var material := get_shader_material()
	if material == null:
		return
	material.set_shader_parameter("_Progress", clampf(value, 0.0, 1.0))


func get_shader_material() -> ShaderMaterial:
	if effect.material is ShaderMaterial:
		return effect.material as ShaderMaterial
	return null


func hide_effect() -> void:
	set_progress(0.0)
	effect.hide()


func invoke_finished(on_finished: Callable) -> void:
	if on_finished.is_valid():
		on_finished.call()
	transition_finished.emit()
