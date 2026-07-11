extends Control
class_name RecapMenu

@onready var bg: ColorRect = $BG
@onready var title: Label = %Title
@onready var stats: Label = %Stats
@onready var home_button: Button = %HomeButton
@onready var play_button: Button = %PlayButton

const STAGGER_DELAY: float = 0.1
const SHELLDIVER_SLIDE_OFFSET: float = 48.0
const SHELLDIVER_ROTATION: float = -10.0

var title_rest_position: Vector2
var stats_rest_position: Vector2
var home_button_rest_position: Vector2
var play_button_rest_position: Vector2

func _ready() -> void:
	reset_menu()

func reset_menu() -> void:
	hide()
	title.modulate.a = 0.0
	stats.modulate.a = 0.0
	home_button.modulate.a = 0.0
	play_button.modulate.a = 0.0

func show_recap() -> void:
	show()
	GameManager.curr_state = GameManager.GameStates.PAUSED
	await get_tree().process_frame
	cache_rest_transforms()
	hide_recap_elements()

	await animate_bg_fade_in()
	await animate_shell_diver_in(title, title_rest_position)
	await get_tree().create_timer(STAGGER_DELAY).timeout
	await animate_forager_pop_in(stats, stats_rest_position)
	await get_tree().create_timer(STAGGER_DELAY).timeout
	await animate_forager_pop_in_parallel(
		[home_button, play_button],
		[home_button_rest_position, play_button_rest_position]
	)


func cache_rest_transforms() -> void:
	title_rest_position = title.position
	stats_rest_position = stats.position
	home_button_rest_position = home_button.position
	play_button_rest_position = play_button.position


func hide_recap_elements() -> void:
	bg.modulate.a = 0.0
	reset_control_for_shell_diver(title, title_rest_position)
	reset_control_for_forager(stats, stats_rest_position)
	reset_control_for_forager(home_button, home_button_rest_position)
	reset_control_for_forager(play_button, play_button_rest_position)
	home_button.disabled = true
	play_button.disabled = true


func prepare_pivot(control: Control) -> void:
	if control.pivot_offset.is_zero_approx():
		control.pivot_offset = control.size * 0.5


func reset_control_for_shell_diver(control: Control, rest_position: Vector2) -> void:
	prepare_pivot(control)
	control.modulate.a = 0.0
	control.rotation_degrees = SHELLDIVER_ROTATION
	control.position = rest_position + Vector2(0, SHELLDIVER_SLIDE_OFFSET)


func reset_control_for_forager(control: Control, rest_position: Vector2) -> void:
	prepare_pivot(control)
	control.position = rest_position
	control.scale = Vector2.ZERO
	control.modulate.a = 0.0


## ShellDiver: entra deslizandose con fade y un giro elastico al asentarse.
func animate_shell_diver_in(control: Control, rest_position: Vector2) -> void:
	prepare_pivot(control)

	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(control, "modulate:a", 1.0, 0.35)\
		.set_trans(Tween.TRANS_SINE)\
		.set_ease(Tween.EASE_OUT)
	tween.tween_property(control, "position", rest_position, 0.45)\
		.set_trans(Tween.TRANS_QUART)\
		.set_ease(Tween.EASE_OUT)
	tween.tween_property(control, "rotation_degrees", 0.0, 0.5)\
		.set_trans(Tween.TRANS_BACK)\
		.set_ease(Tween.EASE_OUT)

	Springer.rotate(control, 14.0, 0.0)
	await tween.finished


## Forager: pop elastico desde escala cero, como los items de recompensa.
func animate_forager_pop_in(control: Control, rest_position: Vector2) -> void:
	prepare_pivot(control)
	control.position = rest_position
	control.scale = Vector2.ZERO
	control.modulate.a = 0.0

	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(control, "scale", Vector2.ONE, 0.35)\
		.set_trans(Tween.TRANS_BACK)\
		.set_ease(Tween.EASE_OUT)
	tween.tween_property(control, "modulate:a", 1.0, 0.2)\
		.set_trans(Tween.TRANS_SINE)\
		.set_ease(Tween.EASE_OUT)

	Springer.scale(control, 0.18, 1.0)
	await tween.finished


## Forager en paralelo para los dos botones del recap.
func animate_forager_pop_in_parallel(
	controls: Array[Control],
	rest_positions: Array[Vector2]
) -> void:
	for i in controls.size():
		var control := controls[i]
		prepare_pivot(control)
		control.position = rest_positions[i]
		control.scale = Vector2.ZERO
		control.modulate.a = 0.0

	var tween := create_tween()
	tween.set_parallel(true)
	for control in controls:
		tween.tween_property(control, "scale", Vector2.ONE, 0.35)\
			.set_trans(Tween.TRANS_BACK)\
			.set_ease(Tween.EASE_OUT)
		tween.tween_property(control, "modulate:a", 1.0, 0.2)\
			.set_trans(Tween.TRANS_SINE)\
			.set_ease(Tween.EASE_OUT)
		Springer.scale(control, 0.18, 1.0)

	await tween.finished

	for control in controls:
		if control is BaseButton:
			(control as BaseButton).disabled = false


func animate_bg_fade_in() -> void:
	bg.modulate.a = 0.0
	var tween := create_tween()
	tween.tween_property(bg, "modulate:a", 1.0, 0.25)\
		.set_trans(Tween.TRANS_SINE)\
		.set_ease(Tween.EASE_OUT)
	await tween.finished


func _on_home_button_pressed() -> void:
	await Transition.fade_out(1.0)
	get_tree().change_scene_to_file("res://scenes/zones/base_zone/base_zone.tscn")
	await Transition.fade_in(1.0)


func _on_home_button_mouse_entered() -> void:
	home_button.pivot_offset = home_button.size / 2
	Springer.rotate(home_button, 1000.0 / maxf(home_button.size.x, home_button.size.y))


func _on_play_button_pressed() -> void:
	await Transition.fade_out(1.0)
	get_tree().change_scene_to_file("res://scenes/zones/mine_zone/mine_zone.tscn")
	await Transition.fade_in(1.0)


func _on_play_button_mouse_entered() -> void:
	play_button.pivot_offset = play_button.size / 2
	Springer.rotate(play_button, 1000.0 / maxf(play_button.size.x, play_button.size.y))
