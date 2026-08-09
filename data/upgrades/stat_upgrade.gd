@tool
extends UpgradeResource
class_name StatUpgrade
## Definicion de una mejora. Inspector: elige Stats + Ores + costs/values.
## Compra real: UpgradeManager.purchase(this) — un solo entry point.

enum OperationMode {
	FLAT,
	PERCENT,
	MULTIPLIER,
}

enum OperationType {
	ADD,
	SUBTRACT,
	SET_TRUE,
	SET_FALSE,
}

@export_category("Identity")
## Clave unica de nivel / save (ej. attack, attack_left). Distinta si varios nodos tocan el mismo stat.
@export var id: String = ""
## Stat global que se modifica al comprar (dropdown Stats).
@export var stat_id: int = Stats.PLAYER_DMG
## Ore que se gasta al comprar (dropdown Ores).
@export var cost_ore: int = Ores.GOLD

@export_category("Operation")
@export var operation_type: OperationType = OperationType.ADD
@export var operation_mode: OperationMode = OperationMode.FLAT
@export var display_type: OperationMode = OperationMode.FLAT

@export_category("Levels")
## Costo en ores por nivel (indice 0 = primera compra).
@export var costs: Array[int] = []
## Valor aplicado al stat en cada compra.
@export var values: Array[float] = []


func _get_configuration_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()
	if id.is_empty():
		warnings.append("Asigna id unico para save (ej. attack).")
	if costs.is_empty() or values.is_empty():
		warnings.append("Rellena costs y values.")
	elif costs.size() != values.size():
		warnings.append("costs y values deben tener el mismo tamano.")
	return warnings


func get_max_level() -> int:
	return mini(costs.size(), values.size())


func get_cost(level_index: int) -> int:
	if level_index < 0 or level_index >= costs.size():
		return 0
	return costs[level_index]


func get_value(level_index: int) -> float:
	if level_index < 0 or level_index >= values.size():
		return 0.0
	return values[level_index]


## Aplica un delta al StatsData vivo (una compra = una llamada).
func apply_value_to(stats: StatsData, amount: float) -> void:
	if stats == null:
		return
	stats.modify_stat(stat_id, amount, operation_mode, operation_type)
