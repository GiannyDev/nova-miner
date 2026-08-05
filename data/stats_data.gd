extends Resource
class_name StatsData

var attack: float = 60.0
var attack_cooldown: float = 0.5
var oxygen: float = 100.0
var speed: float = 600.0
var laser_length: float = 400.0
var pickup_radius: float = 50.0
var helpers_unlocked: int = 0

## Ores
## Cantidad inicial al entrar a la mina (multiplicada por ore_density_mult).
var starting_ore_amount: int = 200
## Multiplica starting_ore_amount al entrar a la mina (upgrade OreCount).
var ore_density_mult: float = 1.0

## Spawn al destruir
## Probabilidad base de spawnear un ore al destruir uno (upgrade SpawnOnDestroy).
var spawn_on_destroy_amount: float = 1.0
## Ores extra al destruir uno ademas del spawn base (upgrade SpawnXOresWhenOneDestroyed).
var spawn_extra_on_destroy: int = 0
## Probabilidad de spawnear un cluster al destruir uno (upgrade DestroyClusterChance).
var destroy_cluster_chance: float = 100.0
## Cuantos ores forman el cluster cuando destroy_cluster_chance activa.
var destroy_cluster_size: int = 30

## Chunk de spawn
## Celdas extra que suma la ventana de spawn del MineChunk (skills de alcance/velocidad).
var chunk_size_bonus_cells: float = 0.0

func get_stat(stat_name: String) -> float:
	match stat_name:
		"attack":
			return attack
		"attack_left", "attack_right":
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
		"starting_ore_amount":
			return starting_ore_amount
		"ore_density_mult":
			return ore_density_mult
		"spawn_on_destroy_amount":
			return spawn_on_destroy_amount
		"spawn_extra_on_destroy":
			return float(spawn_extra_on_destroy)
		"destroy_cluster_chance":
			return destroy_cluster_chance
		"destroy_cluster_size":
			return float(destroy_cluster_size)
		"chunk_size_bonus_cells":
			return chunk_size_bonus_cells
		_:
			push_warning("Unknown stat: %s" % stat_name)
			return 0.0


func set_stat(stat_name: String, value: float) -> void:
	match stat_name:
		"attack":
			attack = value
		"attack_left", "attack_right":
			attack = value
		"speed":
			speed = value
		"laser_length":
			laser_length = value
		"pickup_radius":
			pickup_radius = value
		"helpers_unlocked":
			helpers_unlocked = int(value)
		"starting_ore_amount":
			starting_ore_amount = value
		"ore_density_mult":
			ore_density_mult = value
		"spawn_on_destroy_amount":
			spawn_on_destroy_amount = value
		"spawn_extra_on_destroy":
			spawn_extra_on_destroy = int(value)
		"destroy_cluster_chance":
			destroy_cluster_chance = value
		"destroy_cluster_size":
			destroy_cluster_size = int(value)
		"chunk_size_bonus_cells":
			chunk_size_bonus_cells = value
		_:
			push_warning("Unknown stat: %s" % stat_name)


func modify_stat(stat_name: String, amount: float, mode: StatUpgrade.OperationMode, op: StatUpgrade.OperationType) -> void:
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
