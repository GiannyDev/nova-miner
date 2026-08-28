extends Resource
class_name MineSpawnProfile
## Cueva generate-once: celdas nuevas son tierra u ore. Minado = hueco permanente.

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

@export_group("Clusters")
## Probabilidad de sellar un blob de ores juntos (sin tierra adentro) al revelar celdas.
@export_range(0.0, 1.0, 0.01) var cluster_chance: float = 0.2
## Cuantos ores forma cada cluster de mapa.
@export var cluster_size: int = 4

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
	var total_weight := get_total_weight()
	if total_weight <= 0.0:
		return CurrencyManager.get_ore_data(fallback_ore_id)

	var roll := randf() * total_weight
	for entry in ore_weights:
		if entry == null or entry.ore_data == null or entry.weight <= 0.0:
			continue
		roll -= entry.weight
		if roll <= 0.0:
			return entry.ore_data

	return CurrencyManager.get_ore_data(fallback_ore_id)


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
