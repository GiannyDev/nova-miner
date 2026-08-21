extends Node
## Stats permanentes: enum + bag. Uso: Stats.get_stat(Stats.PLAYER_SPEED).
## get/set/get_name no se pueden usar: chocan con Object/Node.
## STARTING_ORE_AMOUNT = densidad % de mineral en celdas nuevas (no "mantener N vivos").

enum {
	STARTING_ORE_AMOUNT,
	PLAYER_SPEED,
	PLAYER_DMG,
	PLAYER_ATTACK_COOLDOWN,
	SPAWN_ORE_WHEN_DESTROYED_AMOUNT,
	SPAWN_ON_DESTROY_CHANCE,
	SPAWN_CLUSTER_CHANCE,
	SPAWN_CLUSTER_SIZE,
	DRILL_DURABILITY_MAX,
	PICKUP_RADIUS,
	INVENTORY_SIZE,
	DEPOSIT_TIME,
	REFINEMENT_TIME,
	HELPERS_UNLOCKED,
	UNLOCK_WEAPON_SHOP,
	UNLOCK_REFINEMENT,
	UNLOCK_WORKSHOP,
}

const DEFAULTS: Dictionary[int, float] = {
	## Porcentaje de celdas nuevas que son mineral suelto (12 = 12%). El resto es tierra.
	STARTING_ORE_AMOUNT: 12.0,
	PLAYER_SPEED: 350.0,
	PLAYER_DMG: 8.0,
	PLAYER_ATTACK_COOLDOWN: 0.5,
	SPAWN_ORE_WHEN_DESTROYED_AMOUNT: 0.0,
	SPAWN_ON_DESTROY_CHANCE: 0.0,
	SPAWN_CLUSTER_CHANCE: 0.0,
	SPAWN_CLUSTER_SIZE: 3.0,
	DRILL_DURABILITY_MAX: 40.0,
	PICKUP_RADIUS: 50.0,
	INVENTORY_SIZE: 0.0,
	DEPOSIT_TIME: 0.0,
	REFINEMENT_TIME: 0.0,
	HELPERS_UNLOCKED: 0.0,
	UNLOCK_WEAPON_SHOP: 0.0,
	UNLOCK_REFINEMENT: 0.0,
	UNLOCK_WORKSHOP: 0.0,
}

var values: Dictionary[int, float] = {}


func _ready() -> void:
	reset_to_defaults()


## Copia DEFAULTS al bag vivo (nueva partida / boot).
func reset_to_defaults() -> void:
	values = DEFAULTS.duplicate()


## Valor vivo del stat. 0 si el id no existe.
func get_stat(stat_id: int) -> float:
	if not DEFAULTS.has(stat_id):
		push_warning("Unknown stat id: %d (%s)" % [stat_id, stat_name(stat_id)])
		return 0.0
	return float(values.get(stat_id, DEFAULTS[stat_id]))


## Escribe el valor vivo. Ignora ids desconocidos.
func set_stat(stat_id: int, value: float) -> void:
	if not DEFAULTS.has(stat_id):
		push_warning("Unknown stat id: %d (%s)" % [stat_id, stat_name(stat_id)])
		return
	values[stat_id] = value


## Default de partida (sin upgrades / save). Usado p.ej. para el ratio de animacion.
func get_base(stat_id: int) -> float:
	return float(DEFAULTS.get(stat_id, 0.0))


## Aplica un delta (una compra = una llamada).
func modify(stat_id: int, amount: float, mode: Upgrades.OperationMode, op: Upgrades.OperationType) -> void:
	match op:
		Upgrades.OperationType.SET_TRUE:
			set_stat(stat_id, 1.0)
			return
		Upgrades.OperationType.SET_FALSE:
			set_stat(stat_id, 0.0)
			return

	var current := get_stat(stat_id)
	var new_value := current
	match op:
		Upgrades.OperationType.ADD:
			match mode:
				Upgrades.OperationMode.FLAT:
					new_value = current + amount
				Upgrades.OperationMode.PERCENT:
					new_value = current * (1.0 + amount)
				Upgrades.OperationMode.MULTIPLIER:
					new_value = current * amount
		Upgrades.OperationType.SUBTRACT:
			match mode:
				Upgrades.OperationMode.FLAT:
					new_value = current - amount
				Upgrades.OperationMode.PERCENT:
					new_value = current * (1.0 - amount)
				Upgrades.OperationMode.MULTIPLIER:
					new_value = current / amount if amount != 0.0 else current
	set_stat(stat_id, new_value)


## Snapshot para SaveData (id -> float).
func capture() -> Dictionary:
	var result := {}
	for stat_id in all_ids():
		result[stat_id] = get_stat(stat_id)
	return result


## Restaura desde save. Ids desconocidos se ignoran.
func apply(saved: Dictionary) -> void:
	for key in saved.keys():
		set_stat(int(key), float(saved[key]))


## Nombre estable para debug / UI.
func stat_name(stat_id: int) -> String:
	match int(stat_id):
		STARTING_ORE_AMOUNT: return "starting_ore_amount"
		PLAYER_SPEED: return "player_speed"
		PLAYER_DMG: return "player_dmg"
		PLAYER_ATTACK_COOLDOWN: return "player_attack_cooldown"
		SPAWN_ORE_WHEN_DESTROYED_AMOUNT: return "spawn_ore_when_destroyed_amount"
		SPAWN_ON_DESTROY_CHANCE: return "spawn_on_destroy_chance"
		SPAWN_CLUSTER_CHANCE: return "spawn_cluster_chance"
		SPAWN_CLUSTER_SIZE: return "spawn_cluster_size"
		DRILL_DURABILITY_MAX: return "drill_durability_max"
		PICKUP_RADIUS: return "pickup_radius"
		INVENTORY_SIZE: return "inventory_size"
		DEPOSIT_TIME: return "deposit_time"
		REFINEMENT_TIME: return "refinement_time"
		HELPERS_UNLOCKED: return "helpers_unlocked"
		UNLOCK_WEAPON_SHOP: return "unlock_weapon_shop"
		UNLOCK_REFINEMENT: return "unlock_refinement"
		UNLOCK_WORKSHOP: return "unlock_workshop"
		_:
			return "unknown_%d" % int(stat_id)


## Todos los stats conocidos (save / snapshot).
func all_ids() -> Array[int]:
	var ids: Array[int] = []
	for key in DEFAULTS.keys():
		ids.append(int(key))
	return ids
