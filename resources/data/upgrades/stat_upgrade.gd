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


func apply_upgrade(stats: StatBlock) -> void:
	if stats == null:
		return

	match operation_type:
		OperationType.ADD:
			if operation_mode == OperationMode.FLAT:
				stats.add_flat(stat_name, amount)
			elif operation_mode == OperationMode.PERCENT:
				stats.add_percent(stat_name, amount)
			elif operation_mode == OperationMode.MULTIPLIER:
				stats.add_multiplier(stat_name, amount)
		OperationType.SUBTRACT:
			if operation_mode == OperationMode.FLAT:
				stats.add_flat(stat_name, -amount)
			elif operation_mode == OperationMode.PERCENT:
				stats.add_percent(stat_name, -amount)
			elif operation_mode == OperationMode.MULTIPLIER:
				stats.add_multiplier(stat_name, 1.0 / amount)
		OperationType.SET_TRUE:
			stats.set_flag(stat_name, true)
		OperationType.SET_FALSE:
			stats.set_flag(stat_name, false)
		OperationType.ADD_TO_LIST:
			stats.add_to_list(list_name, stat_name)


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
