class_name Stats
## Registro central de stats del jugador / upgrades.
## Uso: Stats.PLAYER_SPEED, Stats.PLAYER_DMG, etc.

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


## Nombre estable para debug / UI.
static func get_name(stat_id: int) -> String:
	match int(stat_id):
		STARTING_ORE_AMOUNT:
			return "starting_ore_amount"
		PLAYER_SPEED:
			return "player_speed"
		PLAYER_DMG:
			return "player_dmg"
		PLAYER_ATTACK_COOLDOWN:
			return "player_attack_cooldown"
		SPAWN_ORE_WHEN_DESTROYED_AMOUNT:
			return "spawn_ore_when_destroyed_amount"
		SPAWN_ON_DESTROY_CHANCE:
			return "spawn_on_destroy_chance"
		SPAWN_CLUSTER_CHANCE:
			return "spawn_cluster_chance"
		SPAWN_CLUSTER_SIZE:
			return "spawn_cluster_size"
		DRILL_DURABILITY_MAX:
			return "drill_durability_max"
		PICKUP_RADIUS:
			return "pickup_radius"
		INVENTORY_SIZE:
			return "inventory_size"
		DEPOSIT_TIME:
			return "deposit_time"
		REFINEMENT_TIME:
			return "refinement_time"
		HELPERS_UNLOCKED:
			return "helpers_unlocked"
		UNLOCK_WEAPON_SHOP:
			return "unlock_weapon_shop"
		UNLOCK_REFINEMENT:
			return "unlock_refinement"
		UNLOCK_WORKSHOP:
			return "unlock_workshop"
		_:
			return "unknown_%d" % int(stat_id)


## Todos los stats conocidos (save / snapshot).
static func all_ids() -> Array[int]:
	return [
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
	]
