@tool
extends UpgradeResource
class_name StatUpgrade
## Definicion de una mejora por stats: un solo id para save, stat modificado y lookup.
## Creala como .tres o como sub-recurso inline en el UpgradeNode del arbol.

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
	ADD_TO_LIST,
}

@export_category("Identity")
## Id unico: save (GameManager.skill_levels), stat en StatsData y clave del upgrade.
@export var id: String = ""
@export var upgrade_type: UpgradeData.UpgradeType = UpgradeData.UpgradeType.PLAYER
@export var upgrade_material: CurrencyData.CurrencyType = CurrencyData.CurrencyType.MONEY

@export_category("Operation")
@export var operation_type: OperationType = OperationType.ADD
@export var operation_mode: OperationMode = OperationMode.FLAT
## Como se muestra el valor en el popup ({stat_amount}).
@export var display_type: OperationMode = OperationMode.FLAT

@export_category("Levels")
## Precio fijo de cada nivel. Indice 0 = primera compra. El tamano define cuantas veces se puede mejorar.
@export var costs: Array[int] = []
## Valor aplicado en cada compra (mismo indice que costs).
@export var values: Array[float] = []

# Runtime: snapshot que UpgradeManager duplica al comprar.
var amount: float = 0.0
var cost: int = 0


func _get_configuration_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()

	if id.is_empty():
		warnings.append("Asigna id: clave unica para save y stat (ej. attack, spawn_extra_on_destroy).")

	if costs.is_empty() or values.is_empty():
		warnings.append("Rellena costs y values: un par por cada nivel de mejora.")
	elif costs.size() != values.size():
		warnings.append("costs (%d) y values (%d) deben tener el mismo tamano." % [costs.size(), values.size()])

	return warnings


# --- Public API ---
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


func prepare_for_level(level_index: int) -> void:
	amount = get_value(level_index)
	cost = get_cost(level_index)


func apply_upgrade(stats: StatsData) -> void:
	if stats == null or id.is_empty():
		return
	stats.modify_stat(id, amount, operation_mode, operation_type)
