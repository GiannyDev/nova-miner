extends Resource
class_name MineSpawnProfile
## Cueva generate-once: tierra de relleno + vetas de mineral por ruido. Minado = hueco permanente.

@export_group("Safe Zone")
## Celdas vacias al entrar (spawn del player).
@export var start_clearance_cells: int = 1
## NxN tratado como hueco alrededor del player al revelar (2 = 2x2).
@export var safe_zone_size: int = 2

@export_group("Dirt")
@export var dirt_data: OreData
## HP de la tierra. 1 = un golpe.
@export var dirt_hp: float = 1.0

@export_group("Bombs")
## Bloque bomba (misma escena Ore). Chance/HP/radio salen de Stats.
@export var bomb_data: OreData

@export_group("Ore Veins")
## Densidad estilo Rock Bottom. Threshold = 0.7 - density. Mas densidad = vetas mas grandes.
@export_range(0.05, 0.65, 0.01) var ore_vein_density: float = 0.35
## Frecuencia del Perlin en celdas. 0.09 + scale 2 ≈ blobs de 5-7 celdas (ventana 20x20).
@export var ore_vein_frequency: float = 0.09
## Escala extra al samplear (Rock Bottom usa 2x el noise de cueva).
@export var ore_vein_sample_scale: float = 2.0
## Offset Y para que las vetas no coincidan con los tuneles.
@export var ore_vein_y_offset: float = 1000.0
## Octavas FBM (Rock Bottom: 4).
@export_range(1, 8, 1) var ore_vein_octaves: int = 4

@export_group("Walkable Paths")
## Huecos sueltos al revelar (0 = cueva maciza, ~0.15 = rutas tipo Lague).
@export_range(0.0, 1.0, 0.01) var walkable_chance: float = 0.15
## Gusanos de tunel que parten de celdas ya vacias (spawn / tuneles previos).
@export var path_worms: int = 2
## Celdas que recorre cada gusano.
@export var path_worm_length: int = 10
## Radio extra del tunel (0 = 1 celda).
@export var path_width: int = 0
## Probabilidad de doblar en cada paso del gusano.
@export_range(0.0, 1.0, 0.01) var path_turn_chance: float = 0.35

@export_group("Content")
@export var ore_weights: Array[OreSpawnEntry] = []
@export var fallback_ore_id: String = "gold"
@export var fallback_ore_hp: float = 24.0

@export_group("Feel")
## Solo intro de la run. Mid-run los bloques aparecen sin pop-in.
@export var spawn_animation_time: float = 0.3

@export_group("World Perks")
## Cuantos pickups se colocan por run (0 = ninguno).
@export var perk_count: int = 2
## Distancia minima al spawn del player, en celdas.
@export var perk_min_distance_cells: int = 14
@export var perk_pool: Array[PerkData] = []


func get_safe_zone_rect(player_cell: Vector2i) -> Rect2i:
	var size := maxi(safe_zone_size, 1)
	var origin := player_cell - Vector2i((size - 1) / 2, (size - 1) / 2)
	return Rect2i(origin, Vector2i(size, size))


func is_inside_safe_zone(cell: Vector2i, player_cell: Vector2i) -> bool:
	return get_safe_zone_rect(player_cell).has_point(cell)


func pick_ore_data() -> OreData:
	return pick_ore_data_with_roll(randf())


## `roll` en 0..1 (ruido determinista por celda para que una veta sea un solo tipo).
func pick_ore_data_with_roll(roll: float) -> OreData:
	var total_weight := get_total_weight()
	if total_weight <= 0.0:
		return CurrencyManager.get_ore_data(fallback_ore_id)

	var remaining := clampf(roll, 0.0, 1.0) * total_weight
	for entry in ore_weights:
		if entry == null or entry.ore_data == null or entry.weight <= 0.0:
			continue
		remaining -= entry.weight
		if remaining <= 0.0:
			return entry.ore_data

	return CurrencyManager.get_ore_data(fallback_ore_id)


## Threshold Rock Bottom: ruido crudo [-1,1] por encima de (0.7 - density). `density_bonus` suma el upgrade de ore amount.
func get_ore_vein_threshold(density_bonus: float = 0.0) -> float:
	var density := clampf(ore_vein_density + density_bonus, 0.08, 0.62)
	return 0.7 - density


func get_ore_hp(ore_data: OreData, ore_size: OreDefinition.OreSize) -> float:
	if ore_data != null and ore_data.is_dirt:
		return dirt_hp
	if ore_data == null:
		return fallback_ore_hp

	for definition in ore_data.definitions:
		if definition != null and definition.ore_size == ore_size and definition.hp > 0.0:
			return definition.hp

	return fallback_ore_hp


func get_total_weight() -> float:
	var total := 0.0
	for entry in ore_weights:
		if entry != null and entry.ore_data != null and entry.weight > 0.0:
			total += entry.weight
	return total
