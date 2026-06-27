@tool
extends UpgradeResource
class_name StatUpgrade

enum OperationMode { FLAT, PERCENT, MULTIPLIER }
enum OperationType { ADD, SUBTRACT, SET_TRUE, SET_FALSE, ADD_TO_LIST }

@export var upgrade_type: UpgradeData.UpgradeType
@export var upgrade_material: CurrencyData.CurrencyType = CurrencyData.CurrencyType.MONEY
@export var operation_mode: OperationMode
@export var operation_type: OperationType
@export var display_type: OperationMode
@export var upgrade_stats: Array[UpgradeStats] = []
@export var skill_id: String: set = _set_skill_id
@export var stat_name: String
@export var list_name: String
@export var amount: float
@export var cost: int


func apply_upgrade(stats: StatsData) -> void:
	if stats == null:
		return

	stats.modify_stat(stat_name, amount, operation_mode, operation_type)


func _set_skill_id(value: String) -> void:
	skill_id = _generate_random_id() if value == "" else value


func _generate_random_id() -> String:
	var chars := "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
	var id := ""
	for i in range(8):
		id += chars[randi() % chars.length()]
	return id


func _init() -> void:
	if skill_id == "":
		skill_id = _generate_random_id()
