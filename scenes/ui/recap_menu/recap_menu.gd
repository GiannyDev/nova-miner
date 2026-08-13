extends Control
class_name RecapMenu
## Recap de run: paneles juntos (sin texto) → textos en cadena → records_panel.

@export var title_key: String = "RECAP"
@export var blocks_mined_key: String = "BLOCKS_MINED"
@export var damage_dealt_key: String = "DAMAGE_DEALT"
@export var distance_traveled_key: String = "DISTANCE_TRAVELED"

@export_group("Sequence")
@export var panels_in_duration: float = 0.2
@export var delay_before_texts: float = 0.12
@export var text_stagger_delay: float = 0.08
@export var text_count_duration: float = 0.45
@export var delay_before_buttons: float = 0.15
@export var delay_before_records: float = 0.15
@export var records_in_duration: float = 0.45

@onready var bg: ColorRect = $BG
@onready var title: Label = %Title
@onready var records_panel: PanelContainer = $RecordsPanel
@onready var records_title_bg: Panel = %RecordsTitleBg
@onready var record_line_distance: RichTextLabel = %RecordLineDistance
@onready var record_line_blocks: RichTextLabel = %RecordLineBlocks
@onready var record_line_damage: RichTextLabel = %RecordLineDamage
@onready var mineral_displays: Array[StatDisplay] = [%MineralGold, %MineralSilver, %MineralPlatinum]
@onready var run_stat_displays: Array[StatDisplay] = [%StatBlocksMined, %StatDamageDealt, %StatDistance]
@onready var home_button: Button = %HomeButton
@onready var play_button: Button = %PlayButton

var records_panel_init_pos := Vector2(1000, 510)
var records_panel_final_pos := Vector2(1300, 510)
var current_recap: RunRecapData
var has_new_record: bool = false
var last_records_panel_size := Vector2.ZERO

const RECORDS_TITLE_BG_HEIGHT := 61.0


func _ready() -> void:
	reset_menu()
	home_button.text = tr("BTN_BASE")
	play_button.text = tr("BTN_PLAY")
	records_panel.resized.connect(sync_records_title_bg)


func reset_menu() -> void:
	hide()
	title.modulate.a = 0.0
	home_button.modulate.a = 0.0
	play_button.modulate.a = 0.0
	records_panel.modulate.a = 0.0
	records_panel.position = records_panel_init_pos
	records_panel.scale = Vector2.ONE
	has_new_record = false
	for display in all_stat_displays():
		display.modulate.a = 0.0


func show_recap(recap_data: RunRecapData = null) -> void:
	current_recap = recap_data if recap_data != null else RunRecapData.new()
	show()
	GameManager.curr_state = GameManager.GameStates.PAUSED
	await get_tree().process_frame
	populate_stats(current_recap)
	await populate_records_panel(current_recap)
	prepare_hidden_state()
	await animate_recap_sequence()


func populate_stats(recap_data: RunRecapData) -> void:
	title.text = tr(title_key)
	for i in mineral_displays.size():
		var ore_id := recap_data.recap_ore_ids[i] if i < recap_data.recap_ore_ids.size() else ""
		mineral_displays[i].setup("ORE_%s" % ore_id.to_upper(), float(recap_data.get_ore_amount(ore_id)), StatDisplay.DisplayMode.PLAIN_INT)
	run_stat_displays[1].setup(damage_dealt_key, recap_data.damage_dealt, StatDisplay.DisplayMode.COMPACT_NUMBER)
	run_stat_displays[0].setup(blocks_mined_key, float(recap_data.blocks_mined), StatDisplay.DisplayMode.COMPACT_NUMBER)
	run_stat_displays[2].setup(distance_traveled_key, recap_data.distance_traveled, StatDisplay.DisplayMode.DISTANCE)


func populate_records_panel(recap_data: RunRecapData) -> void:
	var beaten := SaveData.apply_run_records(
		recap_data.blocks_mined,
		recap_data.damage_dealt,
		recap_data.distance_traveled
	)
	has_new_record = beaten.blocks or beaten.damage or beaten.distance
	record_line_blocks.text = format_record_line(
		"Blocks",
		str(SaveData.record_blocks_mined),
		beaten.blocks
	)
	record_line_damage.text = format_record_line(
		"Damage",
		StatDisplay.format_compact(SaveData.record_damage_dealt),
		beaten.damage
	)
	record_line_distance.text = format_record_line(
		"Distance",
		"%.0fm" % SaveData.record_distance_traveled,
		beaten.distance
	)
	# El PanelContainer puede cambiar de ancho con textos NEW; sincroniza el bg.
	last_records_panel_size = Vector2.ZERO
	await get_tree().process_frame
	sync_records_title_bg()


## Si el PanelContainer cambio de size, el title bg toma todo el ancho del VBox y alto fijo 61.
func sync_records_title_bg() -> void:
	if records_panel.size.is_equal_approx(last_records_panel_size):
		return
	last_records_panel_size = records_panel.size
	var width = records_title_bg.get_parent().size.x
	var target := Vector2(width, RECORDS_TITLE_BG_HEIGHT)
	records_title_bg.custom_minimum_size = target
	records_title_bg.size = target


func format_record_line(label: String, value_text: String, is_new: bool) -> String:
	if is_new:
		return "[wave][color=#f2c14e]NEW[/color] - %s: %s" % [label, value_text]
	return "[wave]%s: %s" % [label, value_text]


func all_stat_displays() -> Array[StatDisplay]:
	var all: Array[StatDisplay] = []
	all.append_array(mineral_displays)
	all.append_array(run_stat_displays)
	return all


func prepare_hidden_state() -> void:
	bg.modulate.a = 0.0
	title.modulate.a = 0.0
	home_button.modulate.a = 0.0
	home_button.disabled = true
	play_button.modulate.a = 0.0
	play_button.disabled = true
	records_panel.modulate.a = 0.0
	records_panel.position = records_panel_init_pos
	records_panel.scale = Vector2.ONE
	for display in all_stat_displays():
		display.reset_hidden()


func animate_recap_sequence() -> void:
	await fade_in(bg, 0.1)
	await fade_in(title, 0.15)

	# 1) Todos los paneles a la vez, sin textos.
	for display in all_stat_displays():
		display.show_panel(self, panels_in_duration)
	await get_tree().create_timer(panels_in_duration).timeout

	# 2) Textos en cadena arriba → abajo.
	await get_tree().create_timer(delay_before_texts).timeout
	var displays := all_stat_displays()
	for i in displays.size():
		await displays[i].show_text(self, text_count_duration)
		if i < displays.size() - 1:
			await get_tree().create_timer(text_stagger_delay).timeout

	# 3) Records panel.
	await get_tree().create_timer(delay_before_buttons).timeout
	await animate_buttons_in()
	await get_tree().create_timer(delay_before_records).timeout
	await animate_records_panel()


func fade_in(control: CanvasItem, duration: float) -> void:
	control.modulate.a = 0.0
	var tween := get_tree().create_tween()
	tween.tween_property(control, "modulate:a", 1.0, duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	await tween.finished


func animate_records_panel() -> void:
	records_panel.position = records_panel_init_pos
	records_panel.modulate.a = 0.0
	records_panel.scale = Vector2.ONE
	await get_tree().process_frame
	records_panel.pivot_offset = Vector2(0.0, records_panel.size.y * 0.5)

	var tween := get_tree().create_tween()
	tween.set_parallel(true)
	tween.tween_property(records_panel, "position", records_panel_final_pos, records_in_duration).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(records_panel, "modulate:a", 1.0, records_in_duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

	# Solo con record nuevo: crece de izquierda a derecha.
	if has_new_record:
		records_panel.scale = Vector2(0.0, 1.0)
		tween.tween_property(records_panel, "scale:x", 1.0, records_in_duration).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	await tween.finished


func animate_buttons_in() -> void:
	home_button.scale = Vector2.ZERO
	home_button.pivot_offset = Vector2(0.5, 0.5)
	play_button.scale = Vector2.ZERO
	play_button.pivot_offset = Vector2(0.5, 0.5)
	var tween := get_tree().create_tween()
	tween.set_parallel(true)
	tween.tween_property(home_button, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(home_button, "modulate:a", 1.0, 0.2)
	tween.tween_property(play_button, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(play_button, "modulate:a", 1.0, 0.2)
	await tween.finished
	home_button.disabled = false
	play_button.disabled = false


func _on_home_button_pressed() -> void:
	SaveData.save_progress()
	await Transition.fade_out(1.0)
	get_tree().change_scene_to_file("res://scenes/zones/base_zone/base_zone.tscn")
	await Transition.fade_in(1.0)


func _on_home_button_mouse_entered() -> void:
	home_button.pivot_offset = home_button.size / 2.0
	Springer.rotate(home_button, 1000.0 / maxf(home_button.size.x, home_button.size.y))


func _on_play_button_pressed() -> void:
	SaveData.save_progress()
	await Transition.fade_out(1.0)
	get_tree().change_scene_to_file("res://scenes/zones/mine_zone/mine_zone.tscn")
	await Transition.fade_in(1.0)


func _on_play_button_mouse_entered() -> void:
	play_button.pivot_offset = play_button.size / 2.0
	Springer.rotate(play_button, 1000.0 / maxf(play_button.size.x, play_button.size.y))
