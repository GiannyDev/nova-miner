extends Node
class_name OreSpawner
## Genera ores en el MineGrid con clustering y posicion de stack (overlap visual).

# --- Exports ---
@export_category("Spawn")
## Probabilidad de colocar el siguiente ore cerca de uno existente (clustering).
@export var cluster_chance: float = 0.75
## Distancia maxima (en celdas) al buscar una celda dentro de un cluster.
@export var cluster_spread: int = 2
@export var spawn_animation_time: float = 0.3

@export_category("Block Layout")
## Misma layout que MineGrid. Si esta asignada, se aplica al grid en setup().
@export var block_layout: MineBlockLayout
## Debug: spawnea una columna de N bloques apilados en una celda fija para tunear rise/base.
@export var debug_spawn_stack: bool = false
@export var debug_stack_height: int = 3
@export var debug_stack_cell: Vector2i = Vector2i(0, 0)

@export_category("Ore Content")
## OreData a spawnear. Si null, usa CurrencyManager (id default_ore_id).
@export var ore_data: OreData
@export var default_ore_id: String = "gold"

# --- Runtime ---
var grid: MineGrid
var target: Node2D
var spawned_ores: Array[Ore] = []


# --- Public API ---
## Inyecta el grid a usar y el nodo padre (YSort) donde se instancian los ores.
func setup(mine_grid: MineGrid, ore_parent: Node2D) -> void:
	grid = mine_grid
	target = ore_parent
	apply_block_layout_to_grid()


## Genera ore_count ores en clusters, garantizando que el mapa siga transitable.
func generate(ore_count: int) -> void:
	if grid == null or target == null:
		push_error("OreSpawner: grid o target no asignados. Llama setup() primero.")
		return

	clear_ores()
	grid.clear_occupied()
	apply_block_layout_to_grid()

	if debug_spawn_stack:
		spawn_debug_stack()
		return

	var placed_cells: Array[Vector2i] = []
	var placed := 0
	var attempts := 0
	var max_attempts := maxi(ore_count * 200, 1000)

	while placed < ore_count and attempts < max_attempts:
		attempts += 1
		var cell := pick_candidate_cell(placed_cells)
		if not grid.is_free_for_spawn(cell):
			continue

		grid.add_stack_occupation(cell)
		if grid.is_fully_accessible():
			spawn_ore_at_cell(cell, 0)
			placed_cells.append(cell)
			placed += 1
		else:
			grid.remove_stack_occupation(cell)

	if placed < ore_count:
		push_warning("OreSpawner: solo se colocaron %d/%d ores (grid muy lleno o restringido)." % [placed, ore_count])


## Elige una celda candidata: random pura o dentro de un cluster existente.
func pick_candidate_cell(placed_cells: Array[Vector2i]) -> Vector2i:
	var dims := grid.get_grid_dimensions()
	if placed_cells.is_empty() or randf() > cluster_chance:
		return Vector2i(randi() % dims.x, randi() % dims.y)

	var base: Vector2i = placed_cells.pick_random()
	var offset := Vector2i(
		randi_range(-cluster_spread, cluster_spread),
		randi_range(-cluster_spread, cluster_spread)
	)
	return base + offset


## Instancia un ore en celda + indice de stack (0 = base pegado al piso de la celda).
func spawn_ore_at_cell(cell: Vector2i, stack_index: int = 0) -> Ore:
	var ore := Refs.ORE_SCENE.instantiate() as Ore
	target.add_child(ore)
	# Solo mueve el OreBlock padre; Visuals/collider quedan como en ore.tscn.
	ore.global_position = grid.get_ore_world_position(cell, stack_index)
	ore.setup(ore.max_hp, grid, cell, OreDefinition.OreSize.SMALL, stack_index, resolve_ore_data())
	ore.destroyed.connect(_on_ore_destroyed)
	animate_spawn(ore)
	spawned_ores.append(ore)
	return ore


## Resuelve OreData del export o del catalogo de CurrencyManager.
func resolve_ore_data() -> OreData:
	if ore_data != null:
		return ore_data
	return CurrencyManager.get_ore_data(default_ore_id)


## Animacion "plop": aparece escalando desde cero.
func animate_spawn(ore: Ore) -> void:
	ore.scale = Vector2.ZERO
	var tween := create_tween()
	tween.tween_property(ore, "scale", Vector2.ONE, spawn_animation_time)\
		.set_trans(Tween.TRANS_BACK)\
		.set_ease(Tween.EASE_OUT)


func clear_ores() -> void:
	for ore in spawned_ores:
		if is_instance_valid(ore):
			ore.queue_free()
	spawned_ores.clear()


# --- Private helpers (no leading _) ---
## Empuja la layout del spawner al grid para una sola fuente de verdad en runtime.
func apply_block_layout_to_grid() -> void:
	if grid == null:
		return
	if block_layout != null:
		grid.block_layout = block_layout
	grid.ensure_block_layout()
	grid.sync_cell_size_from_layout()


## Columna de prueba: N celdas hacia arriba (Y-), una por bloque, paso = cell_size.y.
func spawn_debug_stack() -> void:
	var base_cell := debug_stack_cell
	if not grid.is_in_bounds(base_cell):
		base_cell = grid.get_center_cell() + Vector2i(-2, 0)

	var height := maxi(debug_stack_height, 1)
	for i in height:
		# Celda con menor Y queda mas arriba en pantalla y forma el stack visual.
		var cell := base_cell + Vector2i(0, -i)
		if not grid.is_in_bounds(cell):
			break
		grid.add_stack_occupation(cell)
		spawn_ore_at_cell(cell, 0)


# --- Signal callbacks ---
func _on_ore_destroyed(ore: Ore) -> void:
	spawned_ores.erase(ore)
