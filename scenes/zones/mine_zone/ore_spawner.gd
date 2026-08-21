extends Node
class_name OreSpawner
## Cueva generate-once: cada celda se decide al revelar la ventana (tierra u ore).
## Minado = hueco permanente. Fuera de ventana se recicla el visual; el kind queda.

enum CellKind { UNKNOWN, DIRT, ORE, MINED }

const CARDINALS: Array[Vector2i] = [
	Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN
]
const DIRT_PATH := "res://data/ores/ore_dirt.tres"

# --- Exports ---
@export_group("Spawn")
@export var profile: MineSpawnProfile
@export var max_spawns_per_frame: int = 48
## Anillo de celdas Unknown fuera de la ventana donde pueden caer extras al minar.
@export var extras_lookahead_cells: int = 4

@export_group("Block Layout")
@export var block_layout: MineBlockLayout

# --- Runtime ---
var grid: MineGrid
var chunk: MineChunk
var pool: OrePool
var target: Node2D
## cell -> Ore vivo en el arbol.
var live_blocks: Dictionary = {}
## cell -> CellKind. Persiste toda la run.
var cell_kinds: Dictionary = {}
## cell -> OreData (solo KIND_ORE).
var cell_ore_data: Dictionary = {}
var spawn_queue: Array[Vector2i] = []
var window_connected: bool = false
## Si true, los bloques salen colapsados para la animacion de intro.
var intro_spawn_mode: bool = false


# --- Built-ins ---
func _process(_delta: float) -> void:
	drain_spawn_queue()


# --- Public API ---
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


func reserve_entry_area(world_position: Vector2) -> void:
	if grid == null:
		return
	grid.reserve_area(grid.world_to_cell(world_position), profile.start_clearance_cells)


## Primera ventana: genera dirt/ore y encola visuales.
func spawn_initial_batch() -> void:
	sync_window()


## Vacia la cola de golpe (intro: todos listos antes de la animacion).
func flush_spawn_queue() -> void:
	while not spawn_queue.is_empty():
		spawn_queued_block(spawn_queue.pop_back())


## Todos los bloques activos crecen a la vez desde abajo.
func play_intro_rise_all(duration: float) -> void:
	for ore in live_blocks.values():
		if is_instance_valid(ore):
			(ore as Ore).play_rise_animation(duration)
	await get_tree().create_timer(duration).timeout


## Extras de perk/skill: convierte celdas Unknown (nunca rellena el tunel).
func spawn_burst_around(source_cell: Vector2i, count: int, _spread: int = -1) -> void:
	stamp_ores_on_unknown(source_cell, count)


func clear_ores() -> void:
	spawn_queue.clear()
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


# --- Private helpers ---
func connect_chunk_signals() -> void:
	if chunk == null or window_connected:
		return
	if not chunk.on_window_moved.is_connected(_on_window_moved):
		chunk.on_window_moved.connect(_on_window_moved)
	window_connected = true


## Cull visuales fuera de ventana, genera Unknown, encola dirt/ore faltantes.
func sync_window() -> void:
	if grid == null or chunk == null or not chunk.has_window:
		push_warning("OreSpawner: la ventana del chunk no esta lista.")
		return

	cull_outside_window()
	generate_unknown_in_window()
	enqueue_missing_visuals()


## Recorta visuales fuera de ventana. El kind (dirt/ore/mined) se queda.
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


## Primera vez que una celda entra a la ventana: clusters, luego densidad, resto tierra.
func generate_unknown_in_window() -> void:
	var available: Dictionary = {}
	var player_cell := get_player_cell()
	var area := chunk.window_cells

	for cy in range(area.position.y, area.end.y):
		for cx in range(area.position.x, area.end.x):
			var cell := Vector2i(cx, cy)
			if get_kind(cell) != CellKind.UNKNOWN:
				continue
			if grid.is_reserved(cell) or profile.is_inside_safe_zone(cell, player_cell):
				set_kind(cell, CellKind.MINED)
				continue
			available[cell] = true

	stamp_map_clusters(available)
	fill_remaining_cells(available)


## Vetas de mapa: blobs 4-conectados sin tierra adentro.
func stamp_map_clusters(available: Dictionary) -> void:
	var size := maxi(profile.cluster_size, 2)
	if size <= 0 or profile.cluster_chance <= 0.0 or available.is_empty():
		return

	var max_count := maxi(1, available.size() / (size * 8))
	for i in max_count:
		if randf() > profile.cluster_chance:
			continue
		var blob := grow_ore_blob(available, size)
		for cell in blob:
			mark_as_ore(cell)
			available.erase(cell)


## Resto de celdas: STARTING_ORE_AMOUNT% mineral suelto, el resto tierra.
func fill_remaining_cells(available: Dictionary) -> void:
	var density := clampf(Stats.get_stat(Stats.STARTING_ORE_AMOUNT) * 0.01, 0.0, 1.0)
	var cells: Array = available.keys()
	for cell in cells:
		if randf() < density:
			mark_as_ore(cell)
		else:
			mark_as_dirt(cell)
		available.erase(cell)


## Blob 4-conectado de `size` ores. Si no llega, fallback a cuadrado ceil(sqrt(n)).
func grow_ore_blob(available: Dictionary, size: int, preferred_seed: Variant = null) -> Array[Vector2i]:
	var empty: Array[Vector2i] = []
	if available.is_empty() or size <= 0:
		return empty

	var seed_cell: Vector2i
	if preferred_seed is Vector2i and available.has(preferred_seed):
		seed_cell = preferred_seed
	else:
		seed_cell = available.keys().pick_random()
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


## Encola dirt/ore de la ventana que aun no tienen visual (respawn al volver).
func enqueue_missing_visuals() -> void:
	var area := chunk.window_cells
	for cy in range(area.position.y, area.end.y):
		for cx in range(area.position.x, area.end.x):
			var cell := Vector2i(cx, cy)
			var kind := get_kind(cell)
			if kind != CellKind.DIRT and kind != CellKind.ORE:
				continue
			if live_blocks.has(cell):
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
	if live_blocks.has(cell):
		return
	if chunk == null or not chunk.is_inside_window(cell):
		return

	var kind := get_kind(cell)
	if kind != CellKind.DIRT and kind != CellKind.ORE:
		return

	spawn_block_at_cell(cell, kind)


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


func handle_destroy_extras(source_cell: Vector2i) -> void:
	var spawn_count := 0
	if randf() <= Stats.get_stat(Stats.SPAWN_ON_DESTROY_CHANCE):
		spawn_count += 1
	spawn_count += int(Stats.get_stat(Stats.SPAWN_ORE_WHEN_DESTROYED_AMOUNT))
	if spawn_count > 0:
		stamp_ores_on_unknown(source_cell, spawn_count)

	if randf() <= Stats.get_stat(Stats.SPAWN_CLUSTER_CHANCE):
		var cluster_size := int(Stats.get_stat(Stats.SPAWN_CLUSTER_SIZE))
		if cluster_size > 0:
			stamp_cluster_on_unknown(source_cell, cluster_size)


## Convierte celdas Unknown del anillo en mineral suelto (nunca rellena MINED).
func stamp_ores_on_unknown(source_cell: Vector2i, count: int) -> void:
	var available := collect_unknown_ahead()
	for i in count:
		if available.is_empty():
			return
		var cell := pick_closest_cell(available, source_cell)
		mark_as_ore(cell)
		available.erase(cell)
		if chunk != null and chunk.is_inside_window(cell):
			enqueue_cell(cell)


## Blob de ores en Unknown, 4-conectados, sin tierra adentro.
func stamp_cluster_on_unknown(source_cell: Vector2i, size: int) -> void:
	var available := collect_unknown_ahead()
	if available.is_empty():
		return
	var blob := grow_ore_blob(available, size, pick_closest_cell(available, source_cell))
	for cell in blob:
		mark_as_ore(cell)
		if chunk != null and chunk.is_inside_window(cell):
			enqueue_cell(cell)


func pick_closest_cell(available: Dictionary, source: Vector2i) -> Vector2i:
	if available.is_empty():
		return source
	var best: Vector2i = available.keys()[0]
	var best_d := 2147483647
	for cell in available.keys():
		var offset: Vector2i = cell - source
		var d := absi(offset.x) + absi(offset.y)
		if d < best_d:
			best_d = d
			best = cell
	return best


## Unknown en el anillo alrededor de la ventana (lookahead), no dentro.
func collect_unknown_ahead() -> Dictionary:
	var available := {}
	if chunk == null or not chunk.has_window:
		return available

	var area := chunk.window_cells.grow(maxi(extras_lookahead_cells, 1))
	for cy in range(area.position.y, area.end.y):
		for cx in range(area.position.x, area.end.x):
			var cell := Vector2i(cx, cy)
			if chunk.is_inside_window(cell):
				continue
			if get_kind(cell) != CellKind.UNKNOWN:
				continue
			if grid != null and grid.is_reserved(cell):
				continue
			available[cell] = true
	return available


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
