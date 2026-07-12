## Guarda estado global, niveles del arbol y stats del jugador con upgrades aplicados.

extends Node

enum GameStates {
	NONE,
	PLAYING,
	PAUSED,
	GAMEOVER,
}

const RAW_ORE_ID := "gold"
const REFINED_ORE_SUFFIX := "_refined"
const TEST_STARTING_ORES := 50

var curr_state: GameStates = GameStates.NONE
var skill_levels: Dictionary = {}
var player_stats: StatsData
var unlocked_weapon_ids: Array[String] = ["laser_basic"]
var equipped_weapon_id: String = "laser_basic"

## Inventario unificado: key = ore id ("gold", "gold_refined"), value = cantidad.
var ore_inventory: Dictionary = {}

@export var player_stats_base: StatsData


func _ready() -> void:
	_init_player_stats()
	add_ore(RAW_ORE_ID, TEST_STARTING_ORES)


func _init_player_stats() -> void:
	if player_stats_base == null:
		player_stats_base = load("res://resources/data/player/player_stats_base.tres")

	player_stats = player_stats_base.duplicate(true)
	UpgradeManager.apply_stats_to_player()


func refresh_player_stats() -> void:
	player_stats = player_stats_base.duplicate(true)
	UpgradeManager.apply_stats_to_player()


func add_ore(ore_id: String, amount: int = 1) -> void:
	ore_inventory[ore_id] = get_ore_count(ore_id) + amount


func remove_ore(ore_id: String, amount: int = 1) -> int:
	var current := get_ore_count(ore_id)
	var removed := mini(current, amount)
	var remaining := current - removed

	if remaining <= 0:
		ore_inventory.erase(ore_id)
	else:
		ore_inventory[ore_id] = remaining

	return removed


func get_ore_count(ore_id: String) -> int:
	return int(ore_inventory.get(ore_id, 0))


func get_refined_id(raw_ore_id: String) -> String:
	return raw_ore_id + REFINED_ORE_SUFFIX


func is_refined_id(ore_id: String) -> bool:
	return ore_id.ends_with(REFINED_ORE_SUFFIX)


func get_raw_ore_total() -> int:
	var total := 0
	for ore_id in ore_inventory.keys():
		if not is_refined_id(ore_id):
			total += get_ore_count(ore_id)
	return total


func has_raw_ores() -> bool:
	return get_raw_ore_total() > 0


## Extrae un ore crudo del inventario. Devuelve su id.
func take_next_raw_ore() -> String:
	for ore_id in ore_inventory.keys():
		if is_refined_id(ore_id):
			continue
		if get_ore_count(ore_id) <= 0:
			continue
		remove_ore(ore_id, 1)
		return ore_id
	return ""


## Regresa el ore a spawnear
func get_ore_with_probabilities() -> PackedScene:
	return null


func prepare_control_pivot(control: Control) -> void:
	if control.pivot_offset.is_zero_approx():
		control.pivot_offset = control.size * 0.5
