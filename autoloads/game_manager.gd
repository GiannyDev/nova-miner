extends Node

enum GameStates {
	NONE,
	INTRO,
	PLAYING,
	PAUSED,
	GAMEOVER,
}

const RAW_ORE_ID := "gold"
const REFINED_ORE_SUFFIX := "_refined"

var curr_state: GameStates = GameStates.NONE
var player_stats: StatsData
var unlocked_weapon_ids: Array[String] = ["drill_basic"]
var equipped_weapon_id: String = "drill_basic"

## Runtime de la run: current durability
var drill_durability_current: float = 0.0
var durability_depleted_emitted: bool = false
var drill_durability_drain_per_frame: float = 5.0

var player_stats_base: StatsData


func _ready() -> void:
	init_locale()
	init_player_stats()
	repair_drill_full()


func init_locale() -> void:
	TranslationServer.set_locale("en")


## Base defaults. SaveData.load_progress (deferred) pisa con valores guardados.
func init_player_stats() -> void:
	if player_stats_base == null:
		player_stats_base = load("res://data/player/player_stats_base.tres")
	player_stats = player_stats_base.duplicate(true)


# --- Drill durability ---
func get_drill_durability() -> float:
	return drill_durability_current


func get_drill_durability_max() -> float:
	if player_stats == null:
		return 0.0
	return maxf(player_stats.get_stat(int(Stats.DRILL_DURABILITY_MAX)), 0.0)


func increase_drill_durability(amount: float) -> void:
	if amount == 0.0 or player_stats == null:
		return
	var new_max := maxf(player_stats.get_stat(int(Stats.DRILL_DURABILITY_MAX)) + amount, 0.0)
	player_stats.set_stat(int(Stats.DRILL_DURABILITY_MAX), new_max)
	SaveData.save_progress()
	EventBus.drill_durability_changed.emit(drill_durability_current, get_drill_durability_max())


func set_drill_durability_max(value: float) -> void:
	if player_stats == null:
		return
	player_stats.set_stat(int(Stats.DRILL_DURABILITY_MAX), maxf(value, 0.0))
	SaveData.save_progress()
	EventBus.drill_durability_changed.emit(drill_durability_current, get_drill_durability_max())


func repair_drill_full() -> void:
	durability_depleted_emitted = false
	drill_durability_current = get_drill_durability_max()
	EventBus.drill_durability_changed.emit(drill_durability_current, get_drill_durability_max())


func consume_drill_durability(delta: float) -> void:
	if curr_state != GameStates.PLAYING:
		return
	if drill_durability_drain_per_frame <= 0:
		return

	drill_durability_current -= drill_durability_drain_per_frame * delta
	EventBus.drill_durability_changed.emit(drill_durability_current, get_drill_durability_max())

	if drill_durability_current <= 0.0 and not durability_depleted_emitted:
		drill_durability_current = 0.0
		durability_depleted_emitted = true
		EventBus.drill_durability_depleted.emit()


func add_ore(ore_id: String, amount: int = 1) -> void:
	CurrencyManager.add_ore_by_id(ore_id, amount)


func remove_ore(ore_id: String, amount: int = 1) -> int:
	return CurrencyManager.remove_ore(ore_id, amount)


func get_ore_count(ore_id: String) -> int:
	return CurrencyManager.get_ore_amount(ore_id)


func get_refined_id(raw_ore_id: String) -> String:
	return raw_ore_id + REFINED_ORE_SUFFIX


func is_refined_id(ore_id: String) -> bool:
	return ore_id.ends_with(REFINED_ORE_SUFFIX)


func get_raw_ore_total() -> int:
	var total := 0
	for ore_id in CurrencyManager.get_ore_amounts_snapshot().keys():
		if not is_refined_id(ore_id):
			total += get_ore_count(ore_id)
	return total


func has_raw_ores() -> bool:
	return get_raw_ore_total() > 0


func take_next_raw_ore() -> String:
	for ore_id in CurrencyManager.get_ore_amounts_snapshot().keys():
		if is_refined_id(ore_id):
			continue
		if get_ore_count(ore_id) <= 0:
			continue
		remove_ore(ore_id, 1)
		return ore_id
	return ""


func get_ore_with_probabilities() -> PackedScene:
	return null


func prepare_control_pivot(control: Control) -> void:
	if control.pivot_offset.is_zero_approx():
		control.pivot_offset = control.size * 0.5
