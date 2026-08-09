extends Resource
class_name WeaponData

enum WeaponUpgradeType {
	DAMAGE,
	MINE_SPEED,
	DURABILITY,
	ORE_BONUS
}

@export var weapon_id: String = ""
@export var weapon_name: String = ""
@export var sprite: Texture2D
@export_multiline var description: String = ""

@export_category("Upgrades")
@export_group("Daño")
@export var upgrade_damage_stats: Array[float]
@export var upgrade_damage_stats_costs: Array[float]

@export_group("Velocidad de Minado")
@export var upgrade_drill_speed: Array[float]
@export var upgrade_drill_speed_costs: Array[float]

@export_group("Durabilidad")
@export var upgrade_drill_durability: Array[float]
@export var upgrade_drill_durability_costs: Array[float]

@export_group("Bonus por Ore")
@export var upgrade_ore_bonus: Array[float]
@export var upgrade_ore_bonus_costs: Array[float]

@export_category("Drill")
## Segundos entre cada tick de dano mientras el drill esta enganchado a un ore.
@export var drill_hit_delay: float = 0.2
## Giro visual del bit mientras perfora (rad/s).
@export var drill_spin_speed: float = 14.0
## Factor de suavizado al rotar el drill hacia la direccion de movimiento.
@export var rotation_smoothing: float = 16.0
## Intensidad del squash Springer en cada golpe (0 = sin feedback).
@export var hit_squash_amount: float = 0.1

## Carga un WeaponData por id desde res://data/weapons/{id}.tres
static func load_by_id(weapon_id: String) -> WeaponData:
	if weapon_id.is_empty():
		return null

	var path := "res://data/weapons/%s.tres" % weapon_id
	if not ResourceLoader.exists(path):
		push_warning("WeaponData: no existe '%s'." % path)
		return null

	return load(path) as WeaponData

static func get_upgrade_name(type: WeaponUpgradeType) -> String:
	match type:
		WeaponUpgradeType.DAMAGE:
			return "Damage"
		WeaponUpgradeType.MINE_SPEED:
			return "Mine Speed"
		WeaponUpgradeType.DURABILITY:
			return "Durability"
		WeaponUpgradeType.ORE_BONUS:
			return "Ore Bonus"
	return "Error"
