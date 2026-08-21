class_name Upgrades
## Catalogo de tipos de mejora. El save distingue nodos por upgrade_id (string);
## el Type es lo que el manager usa para copy, stat y formato.

enum Type {
	ORE_AMOUNT,
	SPEED,
	ATTACK,
	ATTACK_COOLDOWN,
	EXTRA_SPAWN,
	SPAWN_CHANCE,
	CLUSTER_CHANCE,
	CLUSTER_SIZE,
	DRILL_DURABILITY,
	PICKUP_RADIUS,
	INVENTORY_SIZE,
	DEPOSIT_TIME,
	REFINEMENT_TIME,
	HELPERS_UNLOCKED,
	UNLOCK_WEAPON_SHOP,
	UNLOCK_REFINEMENT,
	UNLOCK_WORKSHOP,
}

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


## Nombre estable para save JSON / keys de traduccion.
static func type_name(upgrade_type: Type) -> String:
	match int(upgrade_type):
		Type.ORE_AMOUNT:
			return "ore_amount"
		Type.SPEED:
			return "speed"
		Type.ATTACK:
			return "attack"
		Type.ATTACK_COOLDOWN:
			return "attack_cooldown"
		Type.EXTRA_SPAWN:
			return "extra_spawn"
		Type.SPAWN_CHANCE:
			return "spawn_chance"
		Type.CLUSTER_CHANCE:
			return "cluster_chance"
		Type.CLUSTER_SIZE:
			return "cluster_size"
		Type.DRILL_DURABILITY:
			return "drill_durability"
		Type.PICKUP_RADIUS:
			return "pickup_radius"
		Type.INVENTORY_SIZE:
			return "inventory_size"
		Type.DEPOSIT_TIME:
			return "deposit_time"
		Type.REFINEMENT_TIME:
			return "refinement_time"
		Type.HELPERS_UNLOCKED:
			return "helpers_unlocked"
		Type.UNLOCK_WEAPON_SHOP:
			return "unlock_weapon_shop"
		Type.UNLOCK_REFINEMENT:
			return "unlock_refinement"
		Type.UNLOCK_WORKSHOP:
			return "unlock_workshop"
		_:
			return "unknown_%d" % int(upgrade_type)


## Parsea el string guardado en save. -1 si no existe.
static func from_name(type_name: String) -> int:
	match type_name:
		"ore_amount":
			return Type.ORE_AMOUNT
		"speed":
			return Type.SPEED
		"attack":
			return Type.ATTACK
		"attack_cooldown":
			return Type.ATTACK_COOLDOWN
		"extra_spawn":
			return Type.EXTRA_SPAWN
		"spawn_chance":
			return Type.SPAWN_CHANCE
		"cluster_chance":
			return Type.CLUSTER_CHANCE
		"cluster_size":
			return Type.CLUSTER_SIZE
		"drill_durability":
			return Type.DRILL_DURABILITY
		"pickup_radius":
			return Type.PICKUP_RADIUS
		"inventory_size":
			return Type.INVENTORY_SIZE
		"deposit_time":
			return Type.DEPOSIT_TIME
		"refinement_time":
			return Type.REFINEMENT_TIME
		"helpers_unlocked":
			return Type.HELPERS_UNLOCKED
		"unlock_weapon_shop":
			return Type.UNLOCK_WEAPON_SHOP
		"unlock_refinement":
			return Type.UNLOCK_REFINEMENT
		"unlock_workshop":
			return Type.UNLOCK_WORKSHOP
		_:
			return -1


static func get_stat_id(upgrade_type: int) -> int:
	match int(upgrade_type):
		Type.ORE_AMOUNT:
			return Stats.STARTING_ORE_AMOUNT
		Type.SPEED:
			return Stats.PLAYER_SPEED
		Type.ATTACK:
			return Stats.PLAYER_DMG
		Type.ATTACK_COOLDOWN:
			return Stats.PLAYER_ATTACK_COOLDOWN
		Type.EXTRA_SPAWN:
			return Stats.SPAWN_ORE_WHEN_DESTROYED_AMOUNT
		Type.SPAWN_CHANCE:
			return Stats.SPAWN_ON_DESTROY_CHANCE
		Type.CLUSTER_CHANCE:
			return Stats.SPAWN_CLUSTER_CHANCE
		Type.CLUSTER_SIZE:
			return Stats.SPAWN_CLUSTER_SIZE
		Type.DRILL_DURABILITY:
			return Stats.DRILL_DURABILITY_MAX
		Type.PICKUP_RADIUS:
			return Stats.PICKUP_RADIUS
		Type.INVENTORY_SIZE:
			return Stats.INVENTORY_SIZE
		Type.DEPOSIT_TIME:
			return Stats.DEPOSIT_TIME
		Type.REFINEMENT_TIME:
			return Stats.REFINEMENT_TIME
		Type.HELPERS_UNLOCKED:
			return Stats.HELPERS_UNLOCKED
		Type.UNLOCK_WEAPON_SHOP:
			return Stats.UNLOCK_WEAPON_SHOP
		Type.UNLOCK_REFINEMENT:
			return Stats.UNLOCK_REFINEMENT
		Type.UNLOCK_WORKSHOP:
			return Stats.UNLOCK_WORKSHOP
		_:
			return Stats.PLAYER_DMG


static func title_key(upgrade_type: int) -> String:
	return "UPGRADE_%s_TITLE" % type_name(upgrade_type).to_upper()


static func desc_key(upgrade_type: int) -> String:
	return "UPGRADE_%s_DESC" % type_name(upgrade_type).to_upper()


static func get_operation_type(upgrade_type: int) -> OperationType:
	match int(upgrade_type):
		Type.UNLOCK_WEAPON_SHOP, Type.UNLOCK_REFINEMENT, Type.UNLOCK_WORKSHOP:
			return OperationType.SET_TRUE
		_:
			return OperationType.ADD


static func get_operation_mode(_upgrade_type: int) -> OperationMode:
	return OperationMode.FLAT


static func get_display_type(upgrade_type: int) -> OperationMode:
	match int(upgrade_type):
		Type.SPAWN_CHANCE, Type.CLUSTER_CHANCE:
			return OperationMode.PERCENT
		_:
			return OperationMode.FLAT
