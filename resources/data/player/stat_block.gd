extends Resource
class_name StatBlock

@export var base_stats: Dictionary = {}
@export var flags: Dictionary = {}
@export var lists: Dictionary = {}

var flat_bonus: Dictionary = {}
var percent_bonus: Dictionary = {}
var multiplier: Dictionary = {}


func get_stat(stat_name: String) -> float:
	var base: float = base_stats.get(stat_name, 0.0)
	var flat: float = flat_bonus.get(stat_name, 0.0)
	var percent: float = percent_bonus.get(stat_name, 0.0)
	var mult: float = multiplier.get(stat_name, 1.0)
	return (base + flat) * (1.0 + percent) * mult


func set_stat(stat_name: String, value: float) -> void:
	base_stats[stat_name] = value


func add_flat(stat_name: String, amount: float) -> void:
	flat_bonus[stat_name] = flat_bonus.get(stat_name, 0.0) + amount


func add_percent(stat_name: String, amount: float) -> void:
	percent_bonus[stat_name] = percent_bonus.get(stat_name, 0.0) + amount


func add_multiplier(stat_name: String, amount: float) -> void:
	if amount <= 0.0:
		return
	multiplier[stat_name] = multiplier.get(stat_name, 1.0) * amount


func get_flag(flag_name: String) -> bool:
	return flags.get(flag_name, false)


func set_flag(flag_name: String, value: bool) -> void:
	flags[flag_name] = value


func add_to_list(list_name: String, content: Variant) -> void:
	if not lists.has(list_name):
		lists[list_name] = []
	if content not in lists[list_name]:
		lists[list_name].append(content)
	lists[list_name].sort()


func clear_modifier() -> void:
	flat_bonus.clear()
	percent_bonus.clear()
	multiplier.clear()
