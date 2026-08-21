extends Node

## upgrade_id -> { "level": int, "type": String }
var levels: Dictionary = {}


## Nivel comprado de un nodo (0 = nada).
func get_level(upgrade_id: String) -> int:
	var entry: Variant = levels.get(upgrade_id, {})
	if typeof(entry) == TYPE_DICTIONARY:
		return int(entry.get("level", 0))
	return int(entry)


## Type guardado junto al id. -1 si el save viejo no tenia type.
func get_saved_type(upgrade_id: String) -> int:
	var entry: Variant = levels.get(upgrade_id, {})
	if typeof(entry) != TYPE_DICTIONARY:
		return -1
	return Upgrades.from_name(str(entry.get("type", "")))


func get_title(upgrade_type: int) -> String:
	return tr(Upgrades.title_key(upgrade_type))


## Reemplaza {value} en la descripcion traducida con el texto ya formateado del nodo.
func get_description(upgrade_type: int, value_text: String) -> String:
	return tr(Upgrades.desc_key(upgrade_type)).format({ "value": value_text })


func can_purchase(node: UpgradeNode) -> bool:
	if node.upgrade_id.is_empty():
		return false
	var level := get_level(node.upgrade_id)
	if level >= node.get_max_level():
		return false
	return CurrencyManager.can_afford_ore_type(node.cost_ore, node.get_cost(level))


## Gasta ore, aplica el value del nivel actual al stat del Type, guarda id+type.
func purchase(node: UpgradeNode) -> bool:
	if not can_purchase(node):
		return false

	var level := get_level(node.upgrade_id)
	var cost: int = node.get_cost(level)
	if not CurrencyManager.spend_ore_type(node.cost_ore, cost):
		return false

	var amount: float = node.get_value(level)
	var stat_id: int = Upgrades.get_stat_id(node.upgrade_type)
	Stats.modify(
		stat_id,
		amount,
		Upgrades.get_operation_mode(node.upgrade_type),
		Upgrades.get_operation_type(node.upgrade_type)
	)

	var new_level := level + 1
	levels[node.upgrade_id] = {
		"level": new_level,
		"type": Upgrades.type_name(node.upgrade_type),
	}

	SaveData.save_progress()
	EventBus.upgrade_purchased.emit(node.upgrade_id, int(node.upgrade_type), new_level)
	EventBus.upgrade_stat_changed.emit(stat_id, Stats.get_stat(stat_id))
	return true


## Carga el save. Acepta formato viejo (id -> int) y nuevo (id -> {level, type}).
func load_levels(saved_levels: Dictionary) -> void:
	levels.clear()
	for upgrade_id in saved_levels.keys():
		levels[str(upgrade_id)] = normalize_entry(saved_levels[upgrade_id])


func normalize_entry(raw: Variant) -> Dictionary:
	if typeof(raw) == TYPE_DICTIONARY:
		var type_value: Variant = raw.get("type", "")
		var type_name := str(type_value)
		if typeof(type_value) == TYPE_FLOAT or typeof(type_value) == TYPE_INT:
			type_name = Upgrades.type_name(int(type_value))
		return {
			"level": int(raw.get("level", 0)),
			"type": type_name,
		}
	return { "level": int(raw), "type": "" }
