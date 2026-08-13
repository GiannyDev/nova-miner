extends Resource
class_name StatsData
## Stats permanentes del jugador. Lookup por Stats enum (int), no por String.

var attack: float = 8.0
var attack_cooldown: float = 0.5
var speed: float = 350.0
var pickup_radius: float = 50.0
var helpers_unlocked: int = 0

var deposit_time: float = 0.0
var refiniment_time: float = 0.0

var inventory_size: int = 0

var unlock_weapon_shop: bool = false
var unlock_refinement: bool = false
var unlock_workshop: bool = false

## Cantidad objetivo de ores cerca del player (batch + refill).
var starting_ore_amount: int = 12

## Extras al destruir.
var spawn_on_destroy_chance: float = 0.0
var spawn_extra_on_destroy: float = 0.0
var destroy_cluster_chance: float = 0.0
var destroy_cluster_size: int = 3

var drill_durability_max: float = 40.0

func get_stat(stat_id: Variant) -> float:
	var id := int(stat_id)
	match id:
		Stats.PLAYER_DMG: return attack
		Stats.PLAYER_ATTACK_COOLDOWN: return attack_cooldown
		Stats.DEPOSIT_TIME: return deposit_time
		Stats.REFINEMENT_TIME: return refiniment_time
		Stats.INVENTORY_SIZE: return float(inventory_size)
		Stats.PLAYER_SPEED: return speed
		Stats.PICKUP_RADIUS: return pickup_radius
		Stats.HELPERS_UNLOCKED: return float(helpers_unlocked)
		Stats.STARTING_ORE_AMOUNT: return float(starting_ore_amount)
		Stats.SPAWN_ON_DESTROY_CHANCE: return spawn_on_destroy_chance
		Stats.SPAWN_ORE_WHEN_DESTROYED_AMOUNT: return spawn_extra_on_destroy
		Stats.SPAWN_CLUSTER_CHANCE: return destroy_cluster_chance
		Stats.SPAWN_CLUSTER_SIZE: return float(destroy_cluster_size)
		Stats.DRILL_DURABILITY_MAX: return drill_durability_max
		Stats.UNLOCK_WEAPON_SHOP: return 1.0 if unlock_weapon_shop else 0.0
		Stats.UNLOCK_REFINEMENT: return 1.0 if unlock_refinement else 0.0
		Stats.UNLOCK_WORKSHOP: return 1.0 if unlock_workshop else 0.0
		_:
			push_warning("Unknown stat id: %d (%s)" % [id, Stats.get_name(id)])
			return 0.0


func set_stat(stat_id: Variant, value: float) -> void:
	var id := int(stat_id)
	match id:
		Stats.PLAYER_DMG:
			attack = value
		Stats.PLAYER_ATTACK_COOLDOWN:
			attack_cooldown = value
		Stats.DEPOSIT_TIME:
			deposit_time = value
		Stats.REFINEMENT_TIME:
			refiniment_time = value
		Stats.INVENTORY_SIZE:
			inventory_size = int(value)
		Stats.PLAYER_SPEED:
			speed = value
		Stats.PICKUP_RADIUS:
			pickup_radius = value
		Stats.HELPERS_UNLOCKED:
			helpers_unlocked = int(value)
		Stats.STARTING_ORE_AMOUNT:
			starting_ore_amount = int(value)
		Stats.SPAWN_ON_DESTROY_CHANCE:
			spawn_on_destroy_chance = value
		Stats.SPAWN_ORE_WHEN_DESTROYED_AMOUNT:
			spawn_extra_on_destroy = value
		Stats.SPAWN_CLUSTER_CHANCE:
			destroy_cluster_chance = value
		Stats.SPAWN_CLUSTER_SIZE:
			destroy_cluster_size = int(value)
		Stats.DRILL_DURABILITY_MAX:
			drill_durability_max = value
		Stats.UNLOCK_WEAPON_SHOP:
			unlock_weapon_shop = value >= 1.0
		Stats.UNLOCK_REFINEMENT:
			unlock_refinement = value >= 1.0
		Stats.UNLOCK_WORKSHOP:
			unlock_workshop = value >= 1.0
		_:
			push_warning("Unknown stat id: %d (%s)" % [id, Stats.get_name(id)])


func modify_stat(stat_id: Variant, amount: float, mode: StatUpgrade.OperationMode, op: StatUpgrade.OperationType) -> void:
	var id := int(stat_id)
	match op:
		StatUpgrade.OperationType.SET_TRUE:
			set_stat(id, 1.0)
			return
		StatUpgrade.OperationType.SET_FALSE:
			set_stat(id, 0.0)
			return

	var current := get_stat(id)
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

	set_stat(id, new_value)
