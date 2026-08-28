extends Node
class_name OreSpawner
## Decide QUE hay en cada celda y spawnea el visual. MineChunk solo dice WHERE (ventana).
##
## Generate-once: al revelar, UNKNOWN pasa a DIRT, ORE o MINED. Nunca se tira de nuevo.
## Minado = MINED para siempre (tunel). Fuera de ventana se recicla el nodo; el kind queda.
## Al volver, dirt/ore reaparecen. MINED sigue vacio.
##
## Pipeline al revelar:
##   1. Huecos de spawn / safe zone
##   2. Rutas caminables (huecos sueltos + gusanos tipo Lague)
##   3. Vetas de mineral
##   4. Extras de perks (capados, nunca rellenan el tunel)
##   5. El resto: densidad % tierra vs mineral
##   6. Bombas: convierten tierra del lote (chance de Stats, 0 = ninguna)
##   7. Huecos de perk reservados (1x1 MINED)
##
## Visuales: cola + max_spawns_per_frame. Intro flushea y los bloques salen colapsados.
## Ayudantes: ensure_generated / mine_cell. No spawnean Ore fuera de ventana.

enum CellKind { UNKNOWN, DIRT, ORE, MINED }

const CARDINALS: Array[Vector2i] = [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]
const DIRT_PATH := "res://data/ores/ore_dirt.tres"
const BOMB_PATH := "res://data/ores/ore_bomb.tres"
## Extras al destruir no pueden convertir mas de esta fraccion de celdas nuevas en ore.
const BONUS_ORE_CAP_FRACTION := 0.2

@export_group("Spawn")
@export var profile: MineSpawnProfile
@export var max_spawns_per_frame: int = 48

@export_group("Block Layout")
@export var block_layout: MineBlockLayout

@export_group("Bomb Blast")
## Delay entre anillos Chebyshev del ripple (anillo 1 es inmediato).
@export var blast_ring_delay: float = 0.05

@export_group("Helper Reveal")
## Lote Chebyshev alrededor de un ayudante al pisar UNKNOWN.
@export var local_generate_radius: int = 2

var grid: MineGrid
var chunk: MineChunk
var pool: OrePool
var target: Node2D
var live_blocks: Dictionary = {}
var cell_kinds: Dictionary = {}
var cell_ore_data: Dictionary = {}
## HP residual al cull / minado logico. Se borra al spawnear visual o al minar.
var cell_hp: Dictionary = {}
## Celda -> PerkData. Al revelar se talla MINED y se avisa.
var pending_perk_cells: Dictionary = {}
var spawn_queue: Array[Vector2i] = []
var window_connected: bool = false
var intro_spawn_mode: bool = false
## Ores extra de perks/upgrades, aplicados al revelar — nunca pisan el tunel.
var pending_bonus_ores: int = 0

signal perk_cell_carved(cell: Vector2i, perk_data: PerkData)


func _process(_delta: float) -> void:
	drain_spawn_queue()


## Cablea grid, chunk, pool y senales. Una vez por run.
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


## Primera ventana: genera kinds y encola visuales.
func spawn_initial_batch() -> void:
	sync_window()


## Vacia la cola de golpe (intro: todos listos antes de la animacion).
func flush_spawn_queue() -> void:
	while not spawn_queue.is_empty():
		spawn_queued_block(spawn_queue.pop_back())


## Todos los bloques vivos crecen desde abajo a la vez (intro).
func play_intro_rise_all(duration: float) -> void:
	for ore in live_blocks.values():
		if is_instance_valid(ore):
			(ore as Ore).play_rise_animation(duration)
	await get_tree().create_timer(duration).timeout


## Extras de perk: se mezclan en el proximo lote revelado, nunca en el tunel.
func spawn_burst_around(_source_cell: Vector2i, count: int, _spread: int = -1) -> void:
	pending_bonus_ores += maxi(count, 0)


## Suelta visuales y borra kinds. No toca el chunk hasta reset().
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
	cell_hp.clear()
	pending_perk_cells.clear()


## Nueva run: visuales, kinds, grid y ventana.
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


## Cull visuales fuera, genera Unknown, encola dirt/ore que falten.
func sync_window() -> void:
	if grid == null or chunk == null or not chunk.has_window:
		push_warning("OreSpawner: la ventana del chunk no esta lista.")
		return
	cull_outside_window()
	generate_unknown_in_window()
	enqueue_missing_visuals()


## Recicla el nodo si salio de la ventana. El kind (dirt/ore/mined) se queda.
func cull_outside_window() -> void:
	var to_cull: Array[Vector2i] = []
	for cell in live_blocks.keys():
		if not chunk.is_inside_window(cell):
			to_cull.append(cell)
	for cell in to_cull:
		var ore: Ore = live_blocks[cell]
		live_blocks.erase(cell)
		if is_instance_valid(ore) and ore.is_alive():
			cell_hp[cell] = ore.current_hp
		if grid.is_occupied(cell):
			grid.remove_stack_occupation(cell)
		if is_instance_valid(ore):
			release_ore(ore)


# --- Generate-once ---
## Solo celdas UNKNOWN de esta ventana. El resto ya tiene kind de un reveal anterior.
func generate_unknown_in_window() -> void:
	var available := collect_unknown_in_window()
	generate_available_batch(available, true)


## Set de celdas de la ventana que todavia no se decidieron.
func collect_unknown_in_window() -> Dictionary:
	var available := {}
	var area := chunk.window_cells
	for cy in range(area.position.y, area.end.y):
		for cx in range(area.position.x, area.end.x):
			var cell := Vector2i(cx, cy)
			if is_unknown(cell):
				available[cell] = true
	return available


## Pipeline compartido: ventana del player o lote local de un ayudante.
func generate_available_batch(available: Dictionary, include_player_holes: bool) -> void:
	carve_pending_perk_cells(available)
	if include_player_holes:
		carve_spawn_holes(available)
	else:
		carve_reserved_cells(available)
	carve_walkable_paths(available)
	stamp_map_clusters(available)
	stamp_bonus_ores(available)
	var dirt_batch := fill_remaining_cells(available)
	stamp_bombs(dirt_batch)


## Reserva un hueco de perk. Al revelar esa celda se talla MINED.
func register_perk_cell(cell: Vector2i, perk_data: PerkData) -> void:
	if perk_data == null:
		return
	pending_perk_cells[cell] = perk_data
	if not is_unknown(cell):
		carve_perk_cell_now(cell)


## UNKNOWN en radio Chebyshev (lote chico para ayudantes).
func collect_unknown_around(center: Vector2i, radius: int) -> Dictionary:
	var available := {}
	var r := maxi(radius, 0)
	for oy in range(-r, r + 1):
		for ox in range(-r, r + 1):
			var cell := center + Vector2i(ox, oy)
			if is_unknown(cell):
				available[cell] = true
	return available


## Genera kinds alrededor de `cell` sin spawnear Ore fuera de ventana.
func ensure_generated(cell: Vector2i) -> void:
	var available := collect_unknown_around(cell, local_generate_radius)
	if available.is_empty():
		return
	var generated: Array = available.keys()
	generate_available_batch(available, false)
	for generated_cell in generated:
		var typed: Vector2i = generated_cell
		if is_solid(typed) and chunk != null and chunk.is_inside_window(typed):
			enqueue_cell(typed)


## Pega a un bloque vivo o descuenta HP logico si esta culled. False si no hay solido.
func mine_cell(cell: Vector2i, damage: float) -> bool:
	ensure_generated(cell)
	if damage <= 0.0 or not is_solid(cell):
		return false
	var live: Ore = live_blocks.get(cell) as Ore
	if owns_live_block(cell, live):
		live.take_damage(damage)
		return true
	var remaining := get_cell_hp(cell) - damage
	if remaining > 0.0:
		cell_hp[cell] = remaining
		return true
	finish_logical_mine(cell)
	return true


func get_cell_world_position(cell: Vector2i) -> Vector2:
	if grid == null:
		return Vector2.ZERO
	return grid.cell_to_world(cell)


## Entrada reservada + safe zone alrededor del player = hueco MINED.
func carve_spawn_holes(available: Dictionary) -> void:
	var player_cell := get_player_cell()
	var cells: Array = available.keys()
	for cell in cells:
		if grid.is_reserved(cell) or profile.is_inside_safe_zone(cell, player_cell):
			carve_cell(cell, available)


## Solo areas reservadas del grid (lote de ayudante: no talla la safe zone del player).
func carve_reserved_cells(available: Dictionary) -> void:
	if grid == null:
		return
	var cells: Array = available.keys()
	for cell in cells:
		if grid.is_reserved(cell):
			carve_cell(cell, available)


## Huecos de perk pendientes que cayeron en este lote.
func carve_pending_perk_cells(available: Dictionary) -> void:
	var cells: Array = pending_perk_cells.keys()
	for cell in cells:
		if available.has(cell):
			carve_perk_cell_now(cell)
			available.erase(cell)


func carve_perk_cell_now(cell: Vector2i) -> void:
	var perk_data: PerkData = pending_perk_cells.get(cell) as PerkData
	if perk_data == null:
		return
	pending_perk_cells.erase(cell)
	if live_blocks.has(cell):
		var ore: Ore = live_blocks[cell]
		live_blocks.erase(cell)
		if grid != null and grid.is_occupied(cell):
			grid.remove_stack_occupation(cell)
		if is_instance_valid(ore):
			release_ore(ore)
	mark_as_mined(cell)
	perk_cell_carved.emit(cell, perk_data)


## Huecos sueltos + gusanos desde tuneles ya abiertos (Sebastian Lague / cueva conectada).
func carve_walkable_paths(available: Dictionary) -> void:
	scatter_walkable(available)
	carve_path_worms(available)


## Cada celda nueva tiene walkable_chance de nacer ya vacia.
func scatter_walkable(available: Dictionary) -> void:
	if profile.walkable_chance <= 0.0 or available.is_empty():
		return
	var cells: Array = available.keys()
	for cell in cells:
		if randf() < profile.walkable_chance:
			carve_cell(cell, available)


## Lanza N gusanos. Si el lote es chico (tira de ventana), puede vaciarse a mitad.
func carve_path_worms(available: Dictionary) -> void:
	if profile.path_worms <= 0 or profile.path_worm_length <= 0:
		return
	for i in profile.path_worms:
		if available.is_empty():
			return
		run_path_worm(available)


## Un gusano: semilla junto a un hueco existente, camina path_worm_length pasos, a veces dobla.
func run_path_worm(available: Dictionary) -> void:
	if available.is_empty():
		return
	var cell := pick_path_seed(available)
	if not available.has(cell):
		return
	var direction: Vector2i = CARDINALS.pick_random()
	for step in profile.path_worm_length:
		if available.is_empty():
			return
		# El paso cayo fuera del lote: pega a un vecino Unknown si hay.
		if not available.has(cell):
			cell = pick_neighbor_in(available, cell)
			if not available.has(cell):
				return
		carve_with_width(cell, available)
		if randf() < profile.path_turn_chance:
			direction = CARDINALS.pick_random()
		cell += direction


## Prefiere celdas pegadas a un MINED (tunel/spawn). Si no hay, cualquier Unknown del lote.
func pick_path_seed(available: Dictionary) -> Vector2i:
	if available.is_empty():
		return Vector2i.ZERO
	var adjacent: Array[Vector2i] = []
	for cell in available.keys():
		if is_adjacent_to_walkable(cell):
			adjacent.append(cell)
	if not adjacent.is_empty():
		return adjacent.pick_random()
	return available.keys().pick_random()


## Vecino cardinal que siga en el lote. Si no hay, devuelve `from` (el caller sale).
func pick_neighbor_in(available: Dictionary, from: Vector2i) -> Vector2i:
	var options: Array[Vector2i] = []
	for dir in CARDINALS:
		var next: Vector2i = from + dir
		if available.has(next):
			options.append(next)
	if options.is_empty():
		return from
	return options.pick_random()


## Talla un cuadrado Chebyshev de radio path_width (0 = 1 celda).
func carve_with_width(center: Vector2i, available: Dictionary) -> void:
	var radius := maxi(profile.path_width, 0)
	for oy in range(-radius, radius + 1):
		for ox in range(-radius, radius + 1):
			var cell := center + Vector2i(ox, oy)
			if available.has(cell):
				carve_cell(cell, available)


## Hueco permanente. Lo saca del lote para que no reciba dirt/ore despues.
func carve_cell(cell: Vector2i, available: Dictionary) -> void:
	mark_as_mined(cell)
	available.erase(cell)


## Vetas 4-conectadas. Budget ~ lote * chance / (size * 4): no fuerza 1 cluster por tira chica.
func stamp_map_clusters(available: Dictionary) -> void:
	var size := maxi(profile.cluster_size, 2)
	if size <= 0 or profile.cluster_chance <= 0.0 or available.is_empty():
		return
	var expected := float(available.size()) * profile.cluster_chance / float(size * 4)
	var budget := int(expected)
	# El resto decimal es un roll extra (ej. expected 2.3 → 2 seguro, 30% de un tercero).
	if randf() < expected - float(budget):
		budget += 1
	for i in budget:
		var blob := grow_ore_blob(available, size)
		for cell in blob:
			mark_as_ore(cell)
			available.erase(cell)


## Gasta pending_bonus_ores en este lote, tope BONUS_ORE_CAP_FRACTION. El resto espera al siguiente.
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


## Lo que queda: STARTING_ORE_AMOUNT% mineral suelto, el resto tierra.
## Devuelve las tierras de este lote para que stamp_bombs no pise vetas ni celdas viejas.
func fill_remaining_cells(available: Dictionary) -> Array[Vector2i]:
	var dirt_batch: Array[Vector2i] = []
	var density := clampf(Stats.get_stat(Stats.STARTING_ORE_AMOUNT) * 0.01, 0.0, 1.0)
	var cells: Array = available.keys()
	for cell in cells:
		var typed_cell: Vector2i = cell
		if randf() < density:
			mark_as_ore(typed_cell)
		else:
			mark_as_dirt(typed_cell)
			dirt_batch.append(typed_cell)
		available.erase(typed_cell)
	return dirt_batch


## Convierte tierra recien generada en bomba. Chance 0 = no hay bombas (sin nodo unlock).
func stamp_bombs(dirt_batch: Array[Vector2i]) -> void:
	var chance := Stats.get_stat(Stats.BOMB_SPAWN_CHANCE)
	if chance <= 0.0 or dirt_batch.is_empty():
		return
	var bomb_data := get_bomb_data()
	if bomb_data == null:
		return
	for cell in dirt_batch:
		if randf() >= chance:
			continue
		mark_as_bomb(cell, bomb_data)


## Blob 4-conectado de `size` ores, sin tierra adentro. Si no llega, fallback a cuadrado.
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


## Cuadrado ceil(sqrt(n)) anclado cerca de la semilla. Todo el cuadrado tiene que estar en el lote.
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
## Dirt/ore de la ventana sin nodo. Al volver de un cull, reencola (el kind ya existia).
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


## Como mucho max_spawns_per_frame por frame. Evita hitch al revelar ~400 celdas.
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


## Saca un Ore del pool, lo sienta en la celda, y lo deja colapsado (intro) o visible (mid-run).
func spawn_block_at_cell(cell: Vector2i, kind: CellKind) -> Ore:
	var ore := acquire_ore()
	if ore == null:
		return null
	var data := get_dirt_data() if kind == CellKind.DIRT else get_ore_data_for_cell(cell)
	ore.visible = false
	ore.global_position = grid.get_ore_world_position(cell, 0)
	ore.reset_physics_interpolation()
	ore.setup(
		take_stored_hp(cell, data),
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


## Acumula ores extra para el siguiente lote. No pinta Unknown adelante (eso llenaba de mineral el frente).
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


## Bomba = kind ORE + OreData.is_bomb. El visual y el drill no cambian de escena.
func mark_as_bomb(cell: Vector2i, bomb_data: OreData) -> void:
	set_kind(cell, CellKind.ORE)
	cell_ore_data[cell] = bomb_data


func mark_as_mined(cell: Vector2i) -> void:
	set_kind(cell, CellKind.MINED)
	cell_ore_data.erase(cell)
	cell_hp.erase(cell)


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


func get_bomb_data() -> OreData:
	if profile.bomb_data != null:
		return profile.bomb_data
	return load(BOMB_PATH) as OreData


## HP de bomba sale de Stats (upgradeable). El resto lo resuelve el profile.
func resolve_block_hp(data: OreData) -> float:
	if data != null and data.is_bomb:
		return maxf(Stats.get_stat(Stats.BOMB_HP), 1.0)
	return profile.get_ore_hp(data, OreDefinition.OreSize.SMALL)


## HP vivo del visual, o el residual de cull, o el max del tipo.
func get_cell_hp(cell: Vector2i) -> float:
	var live: Ore = live_blocks.get(cell) as Ore
	if owns_live_block(cell, live):
		return live.current_hp
	if cell_hp.has(cell):
		return float(cell_hp[cell])
	return resolve_block_hp(get_block_data(cell))


## Consume el HP guardado al respawnear visual (el nodo pasa a ser la fuente).
func take_stored_hp(cell: Vector2i, data: OreData) -> float:
	if cell_hp.has(cell):
		var stored := float(cell_hp[cell])
		cell_hp.erase(cell)
		return stored
	return resolve_block_hp(data)


func get_block_data(cell: Vector2i) -> OreData:
	if get_kind(cell) == CellKind.DIRT:
		return get_dirt_data()
	return get_ore_data_for_cell(cell)


## Mineral de bag (no tierra, no bomba).
func is_mineral_cell(cell: Vector2i) -> bool:
	if get_kind(cell) != CellKind.ORE:
		return false
	var data := get_ore_data_for_cell(cell)
	return data != null and not data.is_dirt and not data.is_bomb


## Culled: credito al bag, recap, extras/bomba. Sin OreDrop.
func finish_logical_mine(cell: Vector2i) -> void:
	var data := get_block_data(cell)
	var was_bomb := data != null and data.is_bomb
	var world_pos := get_cell_world_position(cell)
	if live_blocks.has(cell):
		var leftover: Ore = live_blocks[cell]
		live_blocks.erase(cell)
		if is_instance_valid(leftover):
			release_ore(leftover)
	mark_as_mined(cell)
	if data != null and not data.is_dirt and not data.is_bomb:
		CurrencyManager.add_ore(data, 1)
	EventBus.cell_mined.emit(data)
	if not was_bomb:
		handle_destroy_extras(cell)
		return
	explode_at(cell, world_pos)


func get_player_cell() -> Vector2i:
	if chunk == null or chunk.follow_target == null or grid == null:
		return Vector2i.ZERO
	return grid.world_to_cell(chunk.follow_target.global_position)


## Siguiente bloque vivo mas cercano, a lo sumo `max_cells` (Chebyshev). `exclude` = celdas ya tocadas.
## Se llama por hop (no una lista al inicio) para no usar instancias que el pool ya reciclo.
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


## Chebyshev: max(|dx|, |dy|). Diagonal cuenta como 1 celda.
func cell_distance(a: Vector2i, b: Vector2i) -> int:
	return maxi(absi(a.x - b.x), absi(a.y - b.y))


# --- Bomb blast ---
## Ripple suave: anillo 1 inmediato, luego delay por anillo. Bombas vecinas encadenan al morir.
func explode_at(center: Vector2i, world_pos: Vector2) -> void:
	var radius := maxi(int(Stats.get_stat(Stats.BOMB_RADIUS_CELLS)), 0)
	var damage := Stats.get_stat(Stats.BOMB_DAMAGE)
	play_blast_feel(world_pos, radius)
	if radius <= 0 or damage <= 0.0:
		return
	for ring in range(1, radius + 1):
		if ring > 1:
			if not is_inside_tree():
				return
			await get_tree().create_timer(blast_ring_delay).timeout
		if not is_inside_tree():
			return
		damage_blast_ring(center, ring, damage)


## VFX + shake. El bloque ya esta MINED; esto es solo feel.
func play_blast_feel(world_pos: Vector2, radius: int) -> void:
	if Refs.camera != null:
		Refs.camera.shake_bomb()
	var cell_w := float(grid.get_cell_width()) if grid != null else 256.0
	var cell_h := float(grid.get_cell_height()) if grid != null else 158.0
	var origin := world_pos + Vector2(0.0, -cell_h * 0.5)
	var radius_px := cell_w * float(maxi(radius, 1))
	Effects.explosion(origin, radius_px)


## Pega a los vivos del anillo Chebyshev `ring` (no al centro). El pool puede haber reciclado el nodo.
func damage_blast_ring(center: Vector2i, ring: int, damage: float) -> void:
	for oy in range(-ring, ring + 1):
		for ox in range(-ring, ring + 1):
			if maxi(absi(ox), absi(oy)) != ring:
				continue
			var cell := center + Vector2i(ox, oy)
			mine_cell(cell, damage)


# --- Bool queries ---
func is_live_block(ore: Ore) -> bool:
	return ore != null and is_instance_valid(ore) and ore.is_alive()


## True si ese nodo sigue siendo el bloque de esa celda (el pool no lo reuso en otra).
func owns_live_block(cell: Vector2i, ore: Ore) -> bool:
	return is_live_block(ore) and live_blocks.get(cell) == ore


## True si hay un Ore vivo en esa celda (no culled, no recycled).
func has_live_block(cell: Vector2i) -> bool:
	return owns_live_block(cell, live_blocks.get(cell) as Ore)


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
## El visual se fue: kind = MINED, extras pendientes, nodo al pool. Bombas disparan el blast.
func _on_ore_destroyed(ore: Ore) -> void:
	var cell := ore.grid_cell
	var was_bomb := ore.is_bomb()
	var world_pos := ore.global_position
	if live_blocks.get(cell) == ore:
		live_blocks.erase(cell)
		mark_as_mined(cell)
		if not was_bomb:
			handle_destroy_extras(cell)
	release_ore(ore)
	if was_bomb:
		explode_at(cell, world_pos)


func _on_window_moved(_window_cells: Rect2i) -> void:
	sync_window()
