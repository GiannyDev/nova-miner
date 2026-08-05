extends Control
class_name RecapMenu
## Orquesta el recap: timings de la secuencia viven aqui y se empujan a los StatDisplay hijos.

@export var title_key: String = "RECAP"
@export var blocks_mined_key: String = "BLOCKS_MINED"
@export var damage_dealt_key: String = "DAMAGE_DEALT"
@export var distance_traveled_key: String = "DISTANCE_TRAVELED"

@export_category("Sequence Timing")
@export var bg_fade_duration: float = 0.1

@export_group("ShellDiver (Title + Minerals)")
@export var shell_stagger_delay: float = 0.1
@export var shell_slide_offset: float = 48.0
@export var shell_rotation_deg: float = -10.0
@export var shell_fade_duration: float = 0.35
@export var shell_slide_duration: float = 0.45
@export var shell_rotation_duration: float = 0.5
@export var shell_spring_rotate: float = 14.0

@export_group("Forager (Run Stats + Buttons)")
@export var forager_stagger_delay: float = 0.1
@export var forager_pop_duration: float = 0.35
@export var forager_fade_duration: float = 0.2
@export var forager_spring_scale: float = 0.18

@export_group("Count Up")
@export var count_up_duration: float = 0.55
@export var count_up_trans: Tween.TransitionType = Tween.TRANS_QUART
@export var count_up_ease: Tween.EaseType = Tween.EASE_OUT
@export var value_spring: float = 0.12

@onready var bg: ColorRect = $BG
@onready var title: Label = %Title
@onready var mineral_displays: Array[StatDisplay] = [%MineralGold, %MineralSilver, %MineralPlatinum]
@onready var run_stat_displays: Array[StatDisplay] = [%StatBlocksMined, %StatDamageDealt, %StatDistance]
@onready var home_button: Button = %HomeButton
@onready var play_button: Button = %PlayButton

var title_rest_position: Vector2
var home_button_rest_position: Vector2
var play_button_rest_position: Vector2
var current_recap: RunRecapData
var shell_preset: JuicePreset
var forager_preset: JuicePreset


func _ready() -> void:
	reset_menu()
	home_button.text = tr("BTN_BASE")
	play_button.text = tr("BTN_PLAY")


func reset_menu() -> void:
	hide()
	title.modulate.a = 0.0
	home_button.modulate.a = 0.0
	play_button.modulate.a = 0.0
	for display in mineral_displays:
		if display != null:
			display.modulate.a = 0.0
	for display in run_stat_displays:
		if display != null:
			display.modulate.a = 0.0


func show_recap(recap_data: RunRecapData = null) -> void:
	current_recap = recap_data if recap_data != null else RunRecapData.new()
	rebuild_sequence_presets()
	show()
	GameManager.curr_state = GameManager.GameStates.PAUSED
	await get_tree().process_frame
	cache_rest_transforms()
	populate_stats(current_recap)
	await prepare_hidden_state()
	await animate_recap_sequence()


## Arma presets runtime desde los @export del Recap (fuente unica de timing).
func rebuild_sequence_presets() -> void:
	shell_preset = JuicePreset.new()
	shell_preset.shell_slide_offset = shell_slide_offset
	shell_preset.shell_rotation_deg = shell_rotation_deg
	shell_preset.shell_fade_duration = shell_fade_duration
	shell_preset.shell_slide_duration = shell_slide_duration
	shell_preset.shell_rotation_duration = shell_rotation_duration
	shell_preset.shell_spring_rotate = shell_spring_rotate
	shell_preset.stagger_delay = shell_stagger_delay
	shell_preset.count_up_duration = count_up_duration
	shell_preset.count_up_trans = count_up_trans
	shell_preset.count_up_ease = count_up_ease

	forager_preset = JuicePreset.new()
	forager_preset.forager_pop_duration = forager_pop_duration
	forager_preset.forager_fade_duration = forager_fade_duration
	forager_preset.forager_spring_scale = forager_spring_scale
	forager_preset.stagger_delay = forager_stagger_delay
	forager_preset.count_up_duration = count_up_duration
	forager_preset.count_up_trans = count_up_trans
	forager_preset.count_up_ease = count_up_ease


func populate_stats(recap_data: RunRecapData) -> void:
	title.text = tr(title_key)
	var ore_keys := build_ore_translation_keys(recap_data.recap_ore_ids)
	for i in mineral_displays.size():
		var ore_id := recap_data.recap_ore_ids[i] if i < recap_data.recap_ore_ids.size() else ""
		var key := ore_keys[i] if i < ore_keys.size() else ore_id.to_upper()
		mineral_displays[i].setup(key, float(recap_data.get_ore_amount(ore_id)), StatDisplay.DisplayMode.PLAIN_INT)
	run_stat_displays[0].setup(blocks_mined_key, float(recap_data.blocks_mined), StatDisplay.DisplayMode.COMPACT_NUMBER)
	run_stat_displays[1].setup(damage_dealt_key, recap_data.damage_dealt, StatDisplay.DisplayMode.COMPACT_NUMBER)
	run_stat_displays[2].setup(distance_traveled_key, recap_data.distance_traveled, StatDisplay.DisplayMode.DISTANCE)


func build_ore_translation_keys(ore_ids: Array[String]) -> Array[String]:
	var keys: Array[String] = []
	for ore_id in ore_ids:
		keys.append("ORE_%s" % ore_id.to_upper())
	return keys


func cache_rest_transforms() -> void:
	title_rest_position = title.position
	home_button_rest_position = home_button.position
	play_button_rest_position = play_button.position


func prepare_hidden_state() -> void:
	bg.modulate.a = 0.0
	UIJuice.reset_shell_diver(title, title_rest_position, shell_preset)
	UIJuice.reset_forager(home_button, home_button_rest_position)
	UIJuice.reset_forager(play_button, play_button_rest_position)
	home_button.disabled = true
	play_button.disabled = true
	for display in mineral_displays:
		if display == null:
			continue
		display.configure_from_parent(&"shell_diver", shell_preset, value_spring)
		await display.reset_hidden()
	for display in run_stat_displays:
		if display == null:
			continue
		display.configure_from_parent(&"forager", forager_preset, value_spring)
		await display.reset_hidden()


func animate_recap_sequence() -> void:
	await UIJuice.animate_fade_in(self, bg, bg_fade_duration).finished
	await UIJuice.animate_shell_diver_in(self, title, title_rest_position, shell_preset).finished

	var stagger := 0
	for display in mineral_displays:
		if display == null:
			continue
		await display.reveal(self, stagger)
		stagger += 1

	for display in run_stat_displays:
		if display == null:
			continue
		display.configure_from_parent(&"forager", forager_preset, value_spring)
		await display.reset_hidden()

	stagger = 0
	for display in run_stat_displays:
		if display == null:
			continue
		await display.reveal(self, stagger)
		stagger += 1

	await animate_buttons_in()


func animate_buttons_in() -> void:
	UIJuice.reset_forager(home_button, home_button_rest_position)
	UIJuice.reset_forager(play_button, play_button_rest_position)
	var button_tween := create_tween()
	button_tween.set_parallel(true)
	button_tween.tween_property(home_button, "scale", Vector2.ONE, forager_pop_duration).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	button_tween.tween_property(home_button, "modulate:a", 1.0, forager_fade_duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	button_tween.tween_property(play_button, "scale", Vector2.ONE, forager_pop_duration).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	button_tween.tween_property(play_button, "modulate:a", 1.0, forager_fade_duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	Springer.scale(home_button, forager_spring_scale, 1.0)
	Springer.scale(play_button, forager_spring_scale, 1.0)
	await button_tween.finished
	home_button.disabled = false
	play_button.disabled = false


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
