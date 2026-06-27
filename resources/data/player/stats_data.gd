extends Resource
class_name StatsData

@export var attack: float = 10.0
@export var attack_cooldown: float = 0.5
@export var oxygen: float = 100.0
@export var speed: float = 200.0
@export var laser_length: float = 400.0
@export var pickup_radius: float = 50.0
@export var helpers_unlocked: int = 0


func get_stat(stat_name: String) -> float:
	match stat_name:
		"attack":
			return attack
		"attack_cooldown":
			return attack_cooldown
		"oxygen":
			return oxygen
		"speed":
			return speed
		"laser_length":
			return laser_length
		"pickup_radius":
			return pickup_radius
		"helpers_unlocked":
			return float(helpers_unlocked)
		_:
			push_warning("Unknown stat: %s" % stat_name)
			return 0.0


func set_stat(stat_name: String, value: float) -> void:
	match stat_name:
		"attack":
			attack = value
		"attack_cooldown":
			attack_cooldown = value
		"oxygen":
			oxygen = value
		"speed":
			speed = value
		"laser_length":
			laser_length = value
		"pickup_radius":
			pickup_radius = value
		"helpers_unlocked":
			helpers_unlocked = int(value)
		_:
			push_warning("Unknown stat: %s" % stat_name)


func modify_stat(
	stat_name: String,
	amount: float,
	mode: StatUpgrade.OperationMode,
	op: StatUpgrade.OperationType
) -> void:
	var current := get_stat(stat_name)
	var new_value := current

	match op:
		StatUpgrade.OperationType.ADD:
			match mode:
				StatUpgrade.OperationMode.FLAT:
					new_value = current + amount
				StatUpgrade.OperationMode.PERCENT:
					new_value = current * (1.0 + amount)
				StatUpgrade.OperationMode.MULTIPLIER:
					new_value = current * amount
		StatUpgrade.OperationType.SUBTRACT:
			match mode:
				StatUpgrade.OperationMode.FLAT:
					new_value = current - amount
				StatUpgrade.OperationMode.PERCENT:
					new_value = current * (1.0 - amount)
				StatUpgrade.OperationMode.MULTIPLIER:
					new_value = current / amount if amount != 0.0 else current

	set_stat(stat_name, new_value)
