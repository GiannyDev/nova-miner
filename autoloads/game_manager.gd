## Guarda estado global, niveles del arbol y stats del jugador con upgrades aplicados.

extends Node

enum GameStates {
	NONE,
	PLAYING,
	PAUSED,
	GAMEOVER,
}

var curr_state: GameStates = GameStates.NONE
var skill_levels: Dictionary = {}
var player_stats: StatsData
var unlocked_weapon_ids: Array[String] = ["laser_basic"]
var equipped_weapon_id: String = "laser_basic"

@export var player_stats_base: StatsData


func _ready() -> void:
	_init_player_stats()


func _init_player_stats() -> void:
	if player_stats_base == null:
		player_stats_base = load("res://resources/data/player/player_stats_base.tres")

	player_stats = player_stats_base.duplicate(true)
	UpgradeManager.apply_stats_to_player()


func refresh_player_stats() -> void:
	player_stats = player_stats_base.duplicate(true)
	UpgradeManager.apply_stats_to_player()


func animate_panel_open(
	controls: Array[Control],
	peek_scale: Vector2 = Vector2(1.12, 1.12),
	peek_rotation_degrees: float = 6.0,
	peek_duration: float = 0.01,
	settle_duration: float = 0.05,
	stagger_delay: float = 0.05
) -> void:
	if controls.is_empty():
		return
	await get_tree().process_frame
	for control in controls:
		if not is_instance_valid(control):
			continue
		await animate_panel_control(
			control,
			peek_scale,
			peek_rotation_degrees,
			peek_duration,
			settle_duration
		)
		if stagger_delay > 0.0:
			await get_tree().create_timer(stagger_delay).timeout


func animate_panel_control(
	control: Control,
	peek_scale: Vector2,
	peek_rotation_degrees: float,
	peek_duration: float,
	settle_duration: float
) -> void:
	prepare_control_pivot(control)
	var original_scale := control.scale
	var original_rotation := control.rotation_degrees
	var peeked_scale := Vector2(
		original_scale.x * peek_scale.x,
		original_scale.y * peek_scale.y
	)
	var peeked_rotation := original_rotation + peek_rotation_degrees
	var peek_tween := create_tween()
	peek_tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	peek_tween.tween_property(control, "scale", peeked_scale, peek_duration)
	peek_tween.parallel().tween_property(control, "rotation_degrees", peeked_rotation, peek_duration)
	await peek_tween.finished
	var settle_tween := create_tween()
	settle_tween.set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)
	settle_tween.tween_property(control, "scale", original_scale, settle_duration)
	settle_tween.parallel().tween_property(control, "rotation_degrees", original_rotation, settle_duration)
	await settle_tween.finished


func prepare_control_pivot(control: Control) -> void:
	if control.pivot_offset.is_zero_approx():
		control.pivot_offset = control.size * 0.5
