extends Resource
class_name WeaponData

enum WeaponKind {
	LASER,
	DRILL,
}

@export_group("Identity")
@export var weapon_id: String = ""
@export var weapon_name: String = ""
@export var kind: WeaponKind = WeaponKind.DRILL
@export var sprite: Texture2D
@export_multiline var description: String = ""

@export_group("Combat")
## Multiplicador sobre StatsData.attack al calcular dano por tick de perforacion.
@export var damage_multiplier: float = 1.0

@export_group("Drill")
## Segundos entre cada tick de dano mientras el drill esta enganchado a un ore.
@export var drill_hit_delay: float = 0.2
## Giro visual del bit mientras perfora (rad/s).
@export var drill_spin_speed: float = 14.0
## Factor de suavizado al rotar el drill hacia la direccion de movimiento.
@export var rotation_smoothing: float = 16.0
## Intensidad del squash Springer en cada golpe (0 = sin feedback).
@export var hit_squash_amount: float = 0.1

@export_group("Laser")
@export var laser_max_length: float = 400.0
@export var laser_color: Color = Color(2.454, 0.8, 0.2, 1.0)
@export var laser_line_width: float = 4.0


## Carga un WeaponData por id desde res://data/weapons/{id}.tres
static func load_by_id(weapon_id: String) -> WeaponData:
	if weapon_id.is_empty():
		return null

	var path := "res://data/weapons/%s.tres" % weapon_id
	if not ResourceLoader.exists(path):
		push_warning("WeaponData: no existe '%s'." % path)
		return null

	return load(path) as WeaponData
