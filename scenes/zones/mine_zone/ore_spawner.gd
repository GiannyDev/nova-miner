extends Node
class_name OreSpawner

enum CellKind { UNKNOWN, DIRT, ORE, MINED }

const CARDINALS: Array[Vector2i] = [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]
const DIRT_PATH := "res://data/ores/ore_dirt.tres"
## Extras al destruir no pueden convertir mas de esta fraccion de celdas nuevas en ore.
const BONUS_ORE_CAP_FRACTION := 0.2

@export_group("Spawn")
@export var profile: MineSpawnProfile
@export var max_spawns_per_frame: int = 48

@export_group("Block Layout")
@export var block_layout: MineBlockLayout

var grid: MineGrid
var chunk: MineChunk
var pool: OrePool
var target: Node2D
var live_blocks: Dictionary = {}
var cell_kinds: Dictionary = {}
var cell_ore_data: Dictionary = {}
var spawn_queue: Array[Vector2i] = []
var window_connected: bool = false
var intro_spawn_mode: bool = false
## Ores extra de perks/upgrades, aplicados al revelar — nunca pisan el tunel.
var pending_bonus_ores: int = 0


func _process(_delta: float) -> void:
	drain_spawn_queue()


func setup(mine_grid: MineGrid, mine_chunk: MineChunk, ore_parent: Node2D, ore_pool: OrePool = null) -> void:
	grid = mine_grid
	chunk = mine_chunk
	target = ore_parent
	pool = ore_pool
	ensure_profile()
	apply_block_layout_to_grid()
	connect_chunk_signals()
	randomize()
	set_process(true)


## Reserva el hueco de entrada (spawn del player).
func reserve_entry_area(world_position: Vector2) -> void:
	if grid == null:
		return
	grid.reserve_area(grid.world_to_cell(world_position), profile.start_clearance_cells)


func spawn_initial_batch() -> void:
	sync_window()


## Vacia la cola de golpe (intro: todos listos antes de la animacion).
func flush_spawn_queue() -> void:
	while not spawn_queue.is_empty():
		spawn_queued_block(spawn_queue.pop_back())


func play_intro_rise_all(duration: float) -> void:
	for ore in live_blocks.values():
		if is_instance_valid(ore):
			(ore as Ore).play_rise_animation(duration)
	await get_tree().create_timer(duration).timeout


## Extras de perk: se mezclan en el proximo lote revelado, nunca en el tunel.
func spawn_burst_around(_source_cell: Vector2i, count: int, _spread: int = -1) -> void:
	pending_bonus_ores += maxi(count, 0)


func clear_ores() -> void:
	spawn_queue.clear()
	pending_bonus_ores = 0
	for cell in live_blocks.keys():
		var ore: Ore = live_blocks[cell]
		if is_instance_valid(ore):
			release_ore(ore)
	live_blocks.clear()
	cell_kinds.clear()
	cell_ore_data.clear()


func reset() -> void:
	clear_ores()
	randomize()
	if grid != null:
		grid.reset()
	if chunk != null:
		chunk.reset()


func get_active_ore_count() -> int:
	return live_blocks.size()


# --- Window ---
func connect_chunk_signals() -> void:
	if chunk == null or window_connected:
		return
	if not chunk.on_window_moved.is_connected(_on_window_moved):
		chunk.on_window_moved.connect(_on_window_moved)
	window_connected = true


func sync_window() -> void:
	if grid == null or chunk == null or not chunk.has_window:
		push_warning("OreSpawner: la ventana del chunk no esta lista.")
		return
	cull_outside_window()
	generate_unknown_in_window()
	enqueue_missing_visuals()


func cull_outside_window() -> void:
	var to_cull: Array[Vector2i] = []
	for cell in live_blocks.keys():
		if not chunk.is_inside_window(cell):
			to_cull.append(cell)
	for cell in to_cull:
		var ore: Ore = live_blocks[cell]
		live_blocks.erase(cell)
		if grid.is_occupied(cell):
			grid.remove_stack_occupation(cell)
		if is_instance_valid(ore):
			release_ore(ore)


# --- Generate-once ---
## Pipeline: huecos de spawn → rutas → vetas → extras → densidad tierra/ore.
func generate_unknown_in_window() -> void:
	var available := collect_unknown_in_window()
	carve_spawn_holes(available)
	carve_walkable_paths(available)
	stamp_map_clusters(available)
	stamp_bonus_ores(available)
	fill_remaining_cells(available)


func collect_unknown_in_window() -> Dictionary:
	var available := {}
	var area := chunk.window_cells
	for cy in range(area.position.y, area.end.y):
		for cx in range(area.position.x, area.end.x):
			var cell := Vector2i(cx, cy)
			if is_unknown(cell):
				available[cell] = true
	return available


func carve_spawn_holes(available: Dictionary) -> void:
	var player_cell := get_player_cell()
	var cells: Array = available.keys()
	for cell in cells:
		if grid.is_reserved(cell) or profile.is_inside_safe_zone(cell, player_cell):
			carve_cell(cell, available)


## Huecos sueltos + gusanos desde tuneles ya abiertos (Sebastian Lague / cueva conectada).
func carve_walkable_paths(available: Dictionary) -> void:
	scatter_walkable(available)
	carve_path_worms(available)


func scatter_walkable(available: Dictionary) -> void:
	if profile.walkable_chance <= 0.0 or available.is_empty():
		return
	var cells: Array = available.keys()
	for cell in cells:
		if randf() < profile.walkable_chance:
			carve_cell(cell, available)


func carve_path_worms(available: Dictionary) -> void:
	if profile.path_worms <= 0 or profile.path_worm_length <= 0 or available.is_empty():
		return
	for i in profile.path_worms:
		run_path_worm(available)


func run_path_worm(available: Dictionary) -> void:
	var cell := pick_path_seed(available)
	if not available.has(cell):
		return
	var direction: Vector2i = CARDINALS.pick_random()
	for step in profile.path_worm_length:
		if available.is_empty():
			return
		if not available.has(cell):
			cell = pick_neighbor_in(available, cell)
			if not available.has(cell):
				return
		carve_with_width(cell, available)
		if randf() < profile.path_turn_chance:
			direction = CARDINALS.pick_random()
		cell += direction


func pick_path_seed(available: Dictionary) -> Vector2i:
	var adjacent: Array[Vector2i] = []
	for cell in available.keys():
		if is_adjacent_to_walkable(cell):
			adjacent.append(cell)
	if not adjacent.is_empty():
		return adjacent.pick_random()
	return available.keys().pick_random()


func pick_neighbor_in(available: Dictionary, from: Vector2i) -> Vector2i:
	var options: Array[Vector2i] = []
	for dir in CARDINALS:
		var next: Vector2i = from + dir
		if available.has(next):
			options.append(next)
	if options.is_empty():
		return from
	return options.pick_random()


func carve_with_width(center: Vector2i, available: Dictionary) -> void:
	var radius := maxi(profile.path_width, 0)
	for oy in range(-radius, radius + 1):
		for ox in range(-radius, radius + 1):
			var cell := center + Vector2i(ox, oy)
			if available.has(cell):
				carve_cell(cell, available)


func carve_cell(cell: Vector2i, available: Dictionary) -> void:
	mark_as_mined(cell)
	available.erase(cell)


func stamp_map_clusters(available: Dictionary) -> void:
	var size := maxi(profile.cluster_size, 2)
	if size <= 0 or profile.cluster_chance <= 0.0 or available.is_empty():
		return
	# Esperanza proporcional al lote. Sin forzar 1 cluster por cada tira de ventana.
	var expected := float(available.size()) * profile.cluster_chance / float(size * 4)
	var budget := int(expected)
	if randf() < expected - float(budget):
		budget += 1
	for i in budget:
		var blob := grow_ore_blob(available, size)
		for cell in blob:
			mark_as_ore(cell)
			available.erase(cell)


func stamp_bonus_ores(available: Dictionary) -> void:
	if pending_bonus_ores <= 0 or available.is_empty():
		return
	var cap := maxi(1, int(ceil(float(available.size()) * BONUS_ORE_CAP_FRACTION)))
	var count := mini(pending_bonus_ores, cap)
	pending_bonus_ores -= count
	for i in count:
		if available.is_empty():
			return
		var cell: Vector2i = available.keys().pick_random()
		mark_as_ore(cell)
		available.erase(cell)


func fill_remaining_cells(available: Dictionary) -> void:
	var density := clampf(Stats.get_stat(Stats.STARTING_ORE_AMOUNT) * 0.01, 0.0, 1.0)
	var cells: Array = available.keys()
	for cell in cells:
		if randf() < density:
			mark_as_ore(cell)
		else:
			mark_as_dirt(cell)
		available.erase(cell)


func grow_ore_blob(available: Dictionary, size: int) -> Array[Vector2i]:
	var empty: Array[Vector2i] = []
	if available.is_empty() or size <= 0:
		return empty
	var seed_cell: Vector2i = available.keys().pick_random()
	var blob: Array[Vector2i] = []
	var in_blob := {}
	var frontier: Array[Vector2i] = [seed_cell]
	while blob.size() < size and not frontier.is_empty():
		var idx := randi() % frontier.size()
		var cell: Vector2i = frontier[idx]
		frontier.remove_at(idx)
		if in_blob.has(cell) or not available.has(cell):
			continue
		blob.append(cell)
		in_blob[cell] = true
		for dir in CARDINALS:
			var neighbor: Vector2i = cell + dir
			if available.has(neighbor) and not in_blob.has(neighbor):
				frontier.append(neighbor)
	if blob.size() >= size:
		blob.resize(size)
		return blob
	var square := try_square_blob(available, seed_cell, size)
	if not square.is_empty():
		return square
	return blob


func try_square_blob(available: Dictionary, seed_cell: Vector2i, size: int) -> Array[Vector2i]:
	var empty: Array[Vector2i] = []
	var side := maxi(ceili(sqrt(float(size))), 1)
	for oy in side:
		for ox in side:
			var origin := seed_cell - Vector2i(ox, oy)
			if not square_fits(origin, side, available):
				continue
			var cells: Array[Vector2i] = []
			for y in side:
				for x in side:
					cells.append(origin + Vector2i(x, y))
			return cells
	return empty


func square_fits(origin: Vector2i, side: int, available: Dictionary) -> bool:
	for y in side:
		for x in side:
			if not available.has(origin + Vector2i(x, y)):
				return false
	return true


# --- Visuals ---
func enqueue_missing_visuals() -> void:
	var area := chunk.window_cells
	for cy in range(area.position.y, area.end.y):
		for cx in range(area.position.x, area.end.x):
			var cell := Vector2i(cx, cy)
			if not is_solid(cell) or live_blocks.has(cell):
				continue
			enqueue_cell(cell)


func enqueue_cell(cell: Vector2i) -> void:
	if spawn_queue.has(cell) or live_blocks.has(cell):
		return
	spawn_queue.append(cell)


func drain_spawn_queue() -> void:
	var budget := maxi(max_spawns_per_frame, 1)
	while budget > 0 and not spawn_queue.is_empty():
		spawn_queued_block(spawn_queue.pop_back())
		budget -= 1


func spawn_queued_block(cell: Vector2i) -> void:
	if live_blocks.has(cell) or chunk == null or not chunk.is_inside_window(cell):
		return
	if not is_solid(cell):
		return
	spawn_block_at_cell(cell, get_kind(cell))


func spawn_block_at_cell(cell: Vector2i, kind: CellKind) -> Ore:
	var ore := acquire_ore()
	if ore == null:
		return null
	var data := get_dirt_data() if kind == CellKind.DIRT else get_ore_data_for_cell(cell)
	ore.visible = false
	ore.global_position = grid.get_ore_world_position(cell, 0)
	ore.reset_physics_interpolation()
	ore.setup(
		profile.get_ore_hp(data, OreDefinition.OreSize.SMALL),
		grid,
		cell,
		OreDefinition.OreSize.SMALL,
		0,
		data
	)
	grid.add_stack_occupation(cell)
	ore.on_spawned()
	if intro_spawn_mode:
		ore.prepare_intro_collapsed()
	else:
		ore.show_instantly()
	if not ore.destroyed.is_connected(_on_ore_destroyed):
		ore.destroyed.connect(_on_ore_destroyed)
	live_blocks[cell] = ore
	return ore


func acquire_ore() -> Ore:
	if pool != null:
		return pool.acquire(target)
	var ore := Refs.ORE_SCENE.instantiate() as Ore
	if ore != null:
		target.add_child(ore)
	return ore


func release_ore(ore: Ore) -> void:
	if pool != null:
		pool.release(ore)
		return
	ore.queue_free()


func ensure_profile() -> void:
	if profile == null:
		profile = MineSpawnProfile.new()
		push_warning("OreSpawner: sin MineSpawnProfile asignado, usando valores por defecto.")


func apply_block_layout_to_grid() -> void:
	if grid == null:
		return
	if block_layout != null:
		grid.block_layout = block_layout
	grid.ensure_block_layout()
	grid.sync_cell_size_from_layout()


## Acumula ores extra para el siguiente lote. No pinta Unknown adelante.
func handle_destroy_extras(_source_cell: Vector2i) -> void:
	var bonus := 0
	if randf() <= Stats.get_stat(Stats.SPAWN_ON_DESTROY_CHANCE):
		bonus += 1
	bonus += int(Stats.get_stat(Stats.SPAWN_ORE_WHEN_DESTROYED_AMOUNT))
	if randf() <= Stats.get_stat(Stats.SPAWN_CLUSTER_CHANCE):
		bonus += int(Stats.get_stat(Stats.SPAWN_CLUSTER_SIZE))
	pending_bonus_ores += bonus


func mark_as_ore(cell: Vector2i) -> void:
	set_kind(cell, CellKind.ORE)
	if not cell_ore_data.has(cell):
		cell_ore_data[cell] = profile.pick_ore_data()


func mark_as_dirt(cell: Vector2i) -> void:
	set_kind(cell, CellKind.DIRT)
	cell_ore_data.erase(cell)


func mark_as_mined(cell: Vector2i) -> void:
	set_kind(cell, CellKind.MINED)
	cell_ore_data.erase(cell)


func set_kind(cell: Vector2i, kind: CellKind) -> void:
	cell_kinds[cell] = kind


func get_kind(cell: Vector2i) -> CellKind:
	return cell_kinds.get(cell, CellKind.UNKNOWN) as CellKind


func get_ore_data_for_cell(cell: Vector2i) -> OreData:
	var data: OreData = cell_ore_data.get(cell) as OreData
	if data != null:
		return data
	return profile.pick_ore_data()


func get_dirt_data() -> OreData:
	if profile.dirt_data != null:
		return profile.dirt_data
	return load(DIRT_PATH) as OreData


func get_player_cell() -> Vector2i:
	if chunk == null or chunk.follow_target == null or grid == null:
		return Vector2i.ZERO
	return grid.world_to_cell(chunk.follow_target.global_position)


## Siguiente bloque vivo a lo sumo `max_cells` (Chebyshev) de `from_cell`. `exclude` = celdas ya tocadas.
func get_chain_ore(from_cell: Vector2i, max_cells: int, exclude: Dictionary) -> Ore:
	var best: Ore = null
	var best_d := 2147483647
	var radius := maxi(max_cells, 1)
	for oy in range(-radius, radius + 1):
		for ox in range(-radius, radius + 1):
			var cell := from_cell + Vector2i(ox, oy)
			if exclude.has(cell):
				continue
			var ore: Ore = live_blocks.get(cell) as Ore
			if not is_live_block(ore):
				continue
			var dist := cell_distance(from_cell, cell)
			if dist > radius or dist >= best_d:
				continue
			best_d = dist
			best = ore
	return best


func is_live_block(ore: Ore) -> bool:
	return ore != null and is_instance_valid(ore) and ore.is_alive()


func owns_live_block(cell: Vector2i, ore: Ore) -> bool:
	return is_live_block(ore) and live_blocks.get(cell) == ore


func cell_distance(a: Vector2i, b: Vector2i) -> int:
	return maxi(absi(a.x - b.x), absi(a.y - b.y))


# --- Bool queries ---
func is_unknown(cell: Vector2i) -> bool:
	return get_kind(cell) == CellKind.UNKNOWN


func is_walkable(cell: Vector2i) -> bool:
	return get_kind(cell) == CellKind.MINED


func is_solid(cell: Vector2i) -> bool:
	var kind := get_kind(cell)
	return kind == CellKind.DIRT or kind == CellKind.ORE


func is_adjacent_to_walkable(cell: Vector2i) -> bool:
	for dir in CARDINALS:
		if is_walkable(cell + dir):
			return true
	return false


# --- Signal callbacks ---
func _on_ore_destroyed(ore: Ore) -> void:
	var cell := ore.grid_cell
	if live_blocks.get(cell) == ore:
		live_blocks.erase(cell)
		mark_as_mined(cell)
		handle_destroy_extras(cell)
	release_ore(ore)


func _on_window_moved(_window_cells: Rect2i) -> void:
	sync_window()
