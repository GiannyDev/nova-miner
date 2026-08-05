extends Resource
class_name MineSpawnProfile
## Reglas de contenido de una mina: densidad de ores, clustering, stacks y ores posibles.
## Es lo que cambia entre mapas y subminas; el OreSpawner solo lo ejecuta.

# --- Exports ---
@export_group("Density")
## Fraccion de celdas del tile que reciben ore. 0.52 replica los 220 ores en 21x20 del prototipo.
@export_range(0.0, 1.0, 0.01) var ore_density: float = 0.52
## Celdas libres alrededor del punto de entrada para que el player no nazca enterrado.
@export var start_clearance_cells: int = 1
## Celdas libres alrededor del player mientras se genera: nunca spawnear encima de el.
@export var player_clearance_cells: int = 2

@export_group("Clustering")
## Probabilidad de colocar el siguiente ore pegado a uno ya colocado (vetas en vez de ruido).
@export_range(0.0, 1.0, 0.01) var cluster_chance: float = 0.75
## Distancia maxima en celdas al buscar hueco dentro de un cluster.
@export var cluster_spread: int = 2
## Intentos por ore antes de rendirse (protege el frame si el tile esta muy lleno).
@export var max_attempts_per_ore: int = 12

@export_group("Stacks")
## Probabilidad de que una celda reciba mas de un bloque apilado (profundidad visual).
@export_range(0.0, 1.0, 0.01) var stack_chance: float = 0.0
## Altura maxima del stack cuando toca apilar.
@export var max_stack_height: int = 1

@export_group("Content")
## Ores posibles con su peso. Vacio = se usa fallback_ore_id del catalogo.
@export var ore_weights: Array[OreSpawnEntry] = []
## Ore de respaldo si no hay pesos configurados.
@export var fallback_ore_id: String = "gold"
## HP por bloque cuando el OreData no trae definicion para el size.
@export var fallback_ore_hp: float = 30.0

@export_group("Feel")
## Duracion del "plop" de aparicion de cada bloque.
@export var spawn_animation_time: float = 0.3


# --- Public API ---
## Cuantos ores toca poner en una cantidad de celdas, con el multiplicador de upgrades.
func get_ore_count_for_cells(cell_count: int, density_multiplier: float = 1.0) -> int:
	var density := clampf(ore_density * density_multiplier, 0.0, 1.0)
	return int(round(float(cell_count) * density))


## Elige un OreData por peso; cae al catalogo si no hay entradas validas.
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


## Altura del stack para una celda nueva (1 = un solo bloque).
func get_stack_height() -> int:
	if stack_chance <= 0.0 or max_stack_height <= 1:
		return 1
	if randf() > stack_chance:
		return 1
	return randi_range(2, maxi(max_stack_height, 2))


## HP del bloque segun la definicion del OreData para ese size.
func get_ore_hp(ore_data: OreData, ore_size: OreDefinition.OreSize) -> float:
	if ore_data == null:
		return fallback_ore_hp

	for definition in ore_data.definitions:
		if definition != null and definition.ore_size == ore_size and definition.hp > 0.0:
			return definition.hp

	return fallback_ore_hp


# --- Private helpers (no leading _) ---
func get_total_weight() -> float:
	var total := 0.0
	for entry in ore_weights:
		if entry != null and entry.ore_data != null and entry.weight > 0.0:
			total += entry.weight
	return total
