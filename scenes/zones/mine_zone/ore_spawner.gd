extends Node
class_name OreSpawner

## Probabilidad de colocar el siguiente ore cerca de uno existente (clustering).
@export var cluster_chance: float = 0.75
## Distancia maxima (en celdas) al buscar una celda dentro de un cluster.
@export var cluster_spread: int = 2
@export var spawn_animation_time: float = 0.3

var grid: MineGrid
var target: Node2D
var spawned_ores: Array[Ore] = []


## Inyecta el grid a usar y el nodo padre (YSort) donde se instancian los ores.
func setup(mine_grid: MineGrid, ore_parent: Node2D) -> void:
	grid = mine_grid
	target = ore_parent


## Genera ore_count ores en clusters, garantizando que el mapa siga transitable.
func generate(ore_count: int) -> void:
	if grid == null or target == null:
		push_error("OreSpawner: grid o target no asignados. Llama setup() primero.")
		return

	clear_ores()
	grid.clear_occupied()

	var placed_cells: Array[Vector2i] = []
	var placed := 0
	var attempts := 0
	var max_attempts := maxi(ore_count * 200, 1000)

	while placed < ore_count and attempts < max_attempts:
		attempts += 1
		var cell := pick_candidate_cell(placed_cells)
		if not grid.is_free_for_spawn(cell):
			continue

		grid.set_occupied(cell, true)
		if grid.is_fully_accessible():
			spawn_ore_at_cell(cell)
			placed_cells.append(cell)
			placed += 1
		else:
			grid.set_occupied(cell, false)

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


func spawn_ore_at_cell(cell: Vector2i) -> void:
	var ore := Refs.ORE_SCENE.instantiate() as Ore
	target.add_child(ore)
	ore.global_position = grid.cell_to_world(cell)
	ore.setup(ore.max_hp, grid, cell)
	ore.destroyed.connect(_on_ore_destroyed)
	animate_spawn(ore)
	spawned_ores.append(ore)


func _on_ore_destroyed(ore: Ore) -> void:
	spawned_ores.erase(ore)


## Animacion "plop": aparece escalando desde cero (tomado de la referencia).
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
