extends Node
## Un solo entry point de compra: purchase(upgrade) -> gasta ore, sube nivel, aplica stat, guarda.

## upgrade.id -> nivel comprado (0 = nada).
var levels: Dictionary = {}


func _ready() -> void:
	pass

## Nivel actual de un upgrade por su id de save.
func get_level(upgrade_id: String) -> int:
	return int(levels.get(upgrade_id, 0))


func set_level(upgrade_id: String, level: int) -> void:
	if upgrade_id.is_empty():
		return
	levels[upgrade_id] = maxi(level, 0)


func can_purchase(upgrade: StatUpgrade) -> bool:
	if upgrade == null or upgrade.id.is_empty():
		return false
	var level := get_level(upgrade.id)
	if level >= upgrade.get_max_level():
		return false
	return CurrencyManager.can_afford_ore_type(upgrade.cost_ore, upgrade.get_cost(level))


## Compra: gasta ore -> aplica valor al stat global -> guarda nivel + stats.
func purchase(upgrade: StatUpgrade) -> bool:
	if not can_purchase(upgrade):
		return false

	var level := get_level(upgrade.id)
	var cost := upgrade.get_cost(level)
	if not CurrencyManager.spend_ore_type(upgrade.cost_ore, cost):
		return false

	var amount := upgrade.get_value(level)
	upgrade.apply_value_to(GameManager.player_stats, amount)

	var new_level := level + 1
	levels[upgrade.id] = new_level

	SaveData.save_progress()
	EventBus.upgrade_purchased.emit(upgrade, new_level)
	EventBus.upgrade_stat_changed.emit(upgrade.stat_id, GameManager.player_stats.get_stat(upgrade.stat_id))
	return true


## Carga niveles desde SaveData (UI del arbol).
func load_levels(saved_levels: Dictionary) -> void:
	levels = saved_levels.duplicate()
