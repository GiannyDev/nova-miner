extends Node
## Persistencia: upgrades, stats, bag de ores, records de run + backup del JSON.
## user://nova_miner_save.json (+ .bak.json)

const SAVE_PATH := "user://nova_miner_save.json"
const SAVE_BACKUP_PATH := "user://nova_miner_save.bak.json"

## upgrade.id -> level
var upgrade_levels: Dictionary = {}
## Stats enum int (como String key en JSON) -> float
var stat_values: Dictionary = {}
## ore_id -> amount (raw y refined).
var ore_amounts: Dictionary = {}

## Mejores marcas de run (records del recap).
var record_blocks_mined: int = 0
var record_damage_dealt: float = 0.0
var record_distance_traveled: float = 0.0


func _ready() -> void:
	load_progress()


func save_progress() -> void:
	if GameManager.player_stats != null:
		stat_values = capture_stats(GameManager.player_stats)
	upgrade_levels = UpgradeManager.levels.duplicate()
	ore_amounts = CurrencyManager.capture_ore_amounts()

	backup_existing_save()

	var payload := {
		"upgrade_levels": upgrade_levels,
		"stat_values": stringify_keys(stat_values),
		"ores": ore_amounts.duplicate(),
		"records": {
			"blocks_mined": record_blocks_mined,
			"damage_dealt": record_damage_dealt,
			"distance_traveled": record_distance_traveled,
		},
	}

	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		push_error("SaveData: no se pudo escribir %s" % SAVE_PATH)
		return
	file.store_string(JSON.stringify(payload, "\t"))


func load_progress() -> void:
	if not try_load_from(SAVE_PATH):
		try_load_from(SAVE_BACKUP_PATH)


## Copia el save actual a .bak antes de sobrescribir.
func backup_existing_save() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var src := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if src == null:
		return
	var dst := FileAccess.open(SAVE_BACKUP_PATH, FileAccess.WRITE)
	if dst == null:
		return
	dst.store_string(src.get_as_text())


func try_load_from(path: String) -> bool:
	if not FileAccess.file_exists(path):
		return false

	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return false

	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		push_warning("SaveData: JSON invalido en %s" % path)
		return false

	apply_payload(parsed)
	return true


func apply_payload(data: Dictionary) -> void:
	upgrade_levels = data.get("upgrade_levels", {})
	stat_values = parse_stat_keys(data.get("stat_values", {}))
	ore_amounts = parse_ore_amounts(data.get("ores", {}))

	var records: Dictionary = data.get("records", {})
	record_blocks_mined = int(records.get("blocks_mined", 0))
	record_damage_dealt = float(records.get("damage_dealt", 0.0))
	record_distance_traveled = float(records.get("distance_traveled", 0.0))

	UpgradeManager.load_levels(upgrade_levels)
	CurrencyManager.apply_ore_amounts(ore_amounts)
	if GameManager.player_stats != null and not stat_values.is_empty():
		apply_stats(GameManager.player_stats, stat_values)
		GameManager.repair_drill_full()


## Compara la run vs records; si hay mejora, guarda. Devuelve que marcas se rompieron.
func apply_run_records(blocks_mined: int, damage_dealt: float, distance_traveled: float) -> Dictionary:
	var beaten := {
		"blocks": false,
		"damage": false,
		"distance": false,
	}

	if blocks_mined > record_blocks_mined:
		record_blocks_mined = blocks_mined
		beaten.blocks = true
	if damage_dealt > record_damage_dealt:
		record_damage_dealt = damage_dealt
		beaten.damage = true
	if distance_traveled > record_distance_traveled:
		record_distance_traveled = distance_traveled
		beaten.distance = true

	if beaten.blocks or beaten.damage or beaten.distance:
		save_progress()

	return beaten


func capture_stats(stats: StatsData) -> Dictionary:
	var result := {}
	for stat_id in Stats.all_ids():
		result[stat_id] = stats.get_stat(stat_id)
	return result


func apply_stats(stats: StatsData, values: Dictionary) -> void:
	for key in values.keys():
		stats.set_stat(int(key), float(values[key]))


func parse_ore_amounts(source: Dictionary) -> Dictionary:
	var result := {}
	for key in source.keys():
		var amount := int(source[key])
		if String(key).is_empty() or amount <= 0:
			continue
		result[String(key)] = amount
	return result


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
