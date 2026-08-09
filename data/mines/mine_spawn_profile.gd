extends Resource
class_name MineSpawnProfile
## Reglas de spawn: safe zone, scatter en el chunk, poco bias cerca del player.

# --- Exports ---
@export_group("Safe Zone")
## Celdas libres al entrar (reserva en el punto de entrada).
@export var start_clearance_cells: int = 1
## NxN bloqueado alrededor del player (2 = 2x2). Nunca spawnea aqui durante la run.
@export var safe_zone_size: int = 2

@export_group("Placement")
## Fraccion de spawns que intentan caer cerca del player (resto = random en el chunk).
@export_range(0.0, 1.0, 0.01) var near_player_bias: float = 0.2
## Radio Chebyshev del "cerca" (fuera del safe_zone).
@export var near_spawn_radius: int = 6
## Segundos que una celda minada queda prohibida para respawn.
@export var mined_cell_ban_seconds: float = 1.25

@export_group("Direction Bias")
## De los spawns "cerca", fraccion empujada hacia la direccion de movimiento.
@export_range(0.0, 1.0, 0.01) var forward_bias_ratio: float = 0.35
@export var forward_bias_min_speed: float = 20.0

@export_group("Clustering")
## Probabilidad de pegar el siguiente ore a uno ya colocado (vetas). Nunca reusa la misma celda.
@export_range(0.0, 1.0, 0.01) var cluster_chance: float = 0.25
@export var cluster_spread: int = 2
@export var max_attempts_per_ore: int = 20

@export_group("Overflow")
@export var overflow_ring_cells: int = 2

@export_group("Stacks")
@export_range(0.0, 1.0, 0.01) var stack_chance: float = 0.0
@export var max_stack_height: int = 1

@export_group("Content")
@export var ore_weights: Array[OreSpawnEntry] = []
@export var fallback_ore_id: String = "gold"
@export var fallback_ore_hp: float = 24.0

@export_group("Feel")
@export var spawn_animation_time: float = 0.3


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


func get_stack_height() -> int:
	if stack_chance <= 0.0 or max_stack_height <= 1:
		return 1
	if randf() > stack_chance:
		return 1
	return randi_range(2, maxi(max_stack_height, 2))


func get_ore_hp(ore_data: OreData, ore_size: OreDefinition.OreSize) -> float:
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
