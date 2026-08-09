extends Node
## Persistencia minima: niveles de upgrade + snapshot de stats.
## user://nova_miner_save.json

const SAVE_PATH := "user://nova_miner_save.json"

## upgrade.id -> level
var upgrade_levels: Dictionary = {}
## Stats enum int (como String key en JSON) -> float
var stat_values: Dictionary = {}


func _ready() -> void:
	load_progress()


func save_progress() -> void:
	if GameManager.player_stats != null:
		stat_values = capture_stats(GameManager.player_stats)
	upgrade_levels = UpgradeManager.levels.duplicate()

	var payload := {
		"upgrade_levels": upgrade_levels,
		"stat_values": stringify_keys(stat_values),
	}

	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		push_error("SaveData: no se pudo escribir %s" % SAVE_PATH)
		return
	file.store_string(JSON.stringify(payload, "\t"))


func load_progress() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return

	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		return

	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		return

	var data: Dictionary = parsed
	upgrade_levels = data.get("upgrade_levels", {})
	stat_values = parse_stat_keys(data.get("stat_values", {}))

	UpgradeManager.load_levels(upgrade_levels)
	if GameManager.player_stats != null and not stat_values.is_empty():
		apply_stats(GameManager.player_stats, stat_values)
		GameManager.repair_drill_full()


func capture_stats(stats: StatsData) -> Dictionary:
	var result := {}
	for stat_id in Stats.all_ids():
		result[stat_id] = stats.get_stat(stat_id)
	return result


func apply_stats(stats: StatsData, values: Dictionary) -> void:
	for key in values.keys():
		stats.set_stat(int(key), float(values[key]))


## JSON solo soporta keys string.
func stringify_keys(source: Dictionary) -> Dictionary:
	var result := {}
	for key in source.keys():
		result[str(int(key))] = source[key]
	return result


func parse_stat_keys(source: Dictionary) -> Dictionary:
	var result := {}
	for key in source.keys():
		result[int(key)] = float(source[key])
	return result
