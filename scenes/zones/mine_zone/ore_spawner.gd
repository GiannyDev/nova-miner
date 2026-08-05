extends Node
class_name OreSpawner
## Coloca ores solo cuando toca spawnear: batch inicial (starting_ore_amount) y al destruir (upgrades).
## El MineChunk acota WHERE puede ir cada ore; este nodo decide WHEN y HOW MANY.
## Hot path: _process solo corre mientras queda cola pendiente.

# --- Exports ---
@export_group("Spawn")
## Reglas de contenido de la mina: clustering, stacks y ores posibles.
@export var profile: MineSpawnProfile
## Maximo de bloques instanciados por frame: evita picos al spawnear muchos a la vez.
@export var max_spawns_per_frame: int = 24
## Stat del UpgradeTree que multiplica starting_ore_amount (upgrade OreCount).
@export var starting_amount_mult_stat: String = "ore_density_mult"
## Stats del UpgradeTree que controlan el spawn al destruir un ore.
@export var spawn_on_destroy_chance_stat: String = "spawn_on_destroy_chance"
@export var spawn_extra_on_destroy_stat: String = "spawn_extra_on_destroy"
@export var destroy_cluster_chance_stat: String = "destroy_cluster_chance"
@export var destroy_cluster_size_stat: String = "destroy_cluster_size"

@export_group("Block Layout")
## Misma layout que MineGrid. Si esta asignada, se aplica al grid en setup().
@export var block_layout: MineBlockLayout


# --- Runtime ---
var grid: MineGrid
var chunk: MineChunk
var pool: OrePool
var target: Node2D
var active_ores: Dictionary = {}
## Cola de bloques pendientes: x,y = celda, z = stack_index.
var spawn_queue: Array[Vector3i] = []


# --- Built-ins ---
## Vacia la cola con presupuesto por frame y se apaga sola cuando no queda nada pendiente.
func _process(_delta: float) -> void:
	var budget := maxi(max_spawns_per_frame, 1)

	while budget > 0 and not spawn_queue.is_empty():
		spawn_queued_block(spawn_queue.pop_back())
		budget -= 1

	if spawn_queue.is_empty():
		set_process(false)


# --- Public API ---
## Inyecta grid, chunk, padre de los ores y pool.
func setup(mine_grid: MineGrid, mine_chunk: MineChunk, ore_parent: Node2D, ore_pool: OrePool = null) -> void:
	grid = mine_grid
	chunk = mine_chunk
	target = ore_parent
	pool = ore_pool

	ensure_profile()
	apply_block_layout_to_grid()
	set_process(false)


## Reserva celdas libres alrededor del punto de entrada para que el player no nazca enterrado.
func reserve_entry_area(world_position: Vector2) -> void:
	if grid == null:
		return
	grid.reserve_area(grid.world_to_cell(world_position), profile.start_clearance_cells)


## Batch inicial al entrar a la mina: starting_ore_amount * ore_density_mult dentro de la ventana.
func spawn_initial_batch() -> void:
	if grid == null or chunk == null or not chunk.has_window:
		push_warning("OreSpawner: la ventana del chunk no esta lista para el spawn inicial.")
		return

	var count := get_starting_ore_count()
	if count <= 0:
		return

	spawn_in_area(chunk.window_cells, count)


## Ores extra alrededor de una celda: gancho del upgrade "spawnea X al destruir uno".
func spawn_burst_around(cell: Vector2i, count: int, spread: int = -1) -> void:
	if count <= 0 or grid == null or chunk == null or not chunk.has_window:
		return

	var radius := spread if spread > 0 else maxi(profile.cluster_spread, 1)
	var burst := Rect2i(cell - Vector2i(radius, radius), Vector2i(radius * 2 + 1, radius * 2 + 1))
	var area := intersect_with_window(burst)
	if area.size == Vector2i.ZERO:
		return

	var placed: Array[Vector2i] = [cell]
	for i in count:
		try_queue_cell(area, placed, profile.cluster_chance)


## Recicla todos los bloques activos y vacia la cola (fin de run / reinicio).
func clear_ores() -> void:
	spawn_queue.clear()
	set_process(false)

	for ore in active_ores.keys():
		if is_instance_valid(ore):
			release_ore(ore)
	active_ores.clear()


## Reinicia la mina entera: bloques, ocupacion y ventana del chunk.
func reset() -> void:
	clear_ores()

	if grid != null:
		grid.reset()
	if chunk != null:
		chunk.reset()


func get_active_ore_count() -> int:
	return active_ores.size()


# --- Private helpers (no leading _) ---
## Encola `count` ores en celdas libres del rect, respetando cluster_chance del perfil.
func spawn_in_area(area: Rect2i, count: int, cluster_chance: float = -1.0) -> void:
	var placed: Array[Vector2i] = []
	var chance := cluster_chance if cluster_chance >= 0.0 else profile.cluster_chance

	for i in count:
		try_queue_cell(area, placed, chance)


## Busca hueco (random o pegado a lo ya colocado) y lo encola. false = no habia lugar.
func try_queue_cell(area: Rect2i, placed_cells: Array[Vector2i], cluster_chance: float) -> bool:
	for i in maxi(profile.max_attempts_per_ore, 1):
		var cell := pick_candidate_cell(area, placed_cells, cluster_chance)
		if not can_spawn_at(cell):
			continue

		placed_cells.append(cell)
		enqueue_stack(cell)
		return true

	return false


func pick_candidate_cell(area: Rect2i, placed_cells: Array[Vector2i], cluster_chance: float) -> Vector2i:
	if placed_cells.is_empty() or randf() > cluster_chance:
		return Vector2i(
			randi_range(area.position.x, area.end.x - 1),
			randi_range(area.position.y, area.end.y - 1)
		)

	var base: Vector2i = placed_cells.pick_random()
	var spread := maxi(profile.cluster_spread, 1)
	var cell := base + Vector2i(randi_range(-spread, spread), randi_range(-spread, spread))
	return clamp_cell_to_rect(cell, area)


func clamp_cell_to_rect(cell: Vector2i, cell_rect: Rect2i) -> Vector2i:
	return Vector2i(
		clampi(cell.x, cell_rect.position.x, cell_rect.end.x - 1),
		clampi(cell.y, cell_rect.position.y, cell_rect.end.y - 1)
	)


## Interseccion del burst local con la ventana del chunk (spawn solo dentro del chunk).
func intersect_with_window(area: Rect2i) -> Rect2i:
	if chunk == null or not chunk.has_window:
		return area

	var window := chunk.window_cells
	var min_pos := Vector2i(
		maxi(area.position.x, window.position.x),
		maxi(area.position.y, window.position.y)
	)
	var max_pos := Vector2i(
		mini(area.end.x, window.end.x),
		mini(area.end.y, window.end.y)
	)
	if min_pos.x >= max_pos.x or min_pos.y >= max_pos.y:
		return Rect2i()

	return Rect2i(min_pos, max_pos - min_pos)


## Ocupa la celda al encolar (para que nadie mas la tome) y encola sus bloques apilados.
func enqueue_stack(cell: Vector2i) -> void:
	var height := profile.get_stack_height()

	for stack_index in height:
		grid.add_stack_occupation(cell)
		spawn_queue.append(Vector3i(cell.x, cell.y, stack_index))

	set_process(true)


func spawn_queued_block(entry: Vector3i) -> void:
	var cell := Vector2i(entry.x, entry.y)

	# El player pudo caminar hasta esa celda mientras estaba en cola: mejor liberarla que sepultarlo.
	if is_near_player(cell):
		grid.remove_stack_occupation(cell)
		return

	spawn_ore_at_cell(cell, entry.z)


## Instancia (o recicla) un bloque en celda + indice de stack. No toca la ocupacion del grid.
func spawn_ore_at_cell(cell: Vector2i, stack_index: int = 0) -> Ore:
	var ore := acquire_ore()
	if ore == null:
		return null

	var ore_data := profile.pick_ore_data()
	# Solo mueve el OreBlock padre; Visuals/collider quedan como en ore.tscn.
	ore.global_position = grid.get_ore_world_position(cell, stack_index)
	ore.setup(
		profile.get_ore_hp(ore_data, OreDefinition.OreSize.SMALL),
		grid,
		cell,
		OreDefinition.OreSize.SMALL,
		stack_index,
		ore_data
	)
	ore.on_spawned()
	ore.play_spawn_animation(profile.spawn_animation_time)

	if not ore.destroyed.is_connected(_on_ore_destroyed):
		ore.destroyed.connect(_on_ore_destroyed)

	active_ores[ore] = true
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


## Empuja la layout del spawner al grid para una sola fuente de verdad en runtime.
func apply_block_layout_to_grid() -> void:
	if grid == null:
		return
	if block_layout != null:
		grid.block_layout = block_layout
	grid.ensure_block_layout()
	grid.sync_cell_size_from_layout()


func get_starting_ore_count() -> int:
	var base := 0
	if GameManager.player_stats != null:
		base = int(GameManager.player_stats.get_stat("starting_ore_amount"))
	return int(round(float(base) * get_starting_amount_multiplier()))


func get_starting_amount_multiplier() -> float:
	if starting_amount_mult_stat.is_empty() or GameManager.player_stats == null:
		return 1.0
	return maxf(GameManager.player_stats.get_stat(starting_amount_mult_stat), 0.0)


func get_player_stat(stat_name: String) -> float:
	if stat_name.is_empty() or GameManager.player_stats == null:
		return 0.0
	return GameManager.player_stats.get_stat(stat_name)


## Evalua las stats de destroy-spawn y encola los ores que correspondan cerca de la celda minada.
func handle_destroy_spawns(source_cell: Vector2i) -> void:
	var spawn_count := 0

	if randf() <= get_player_stat(spawn_on_destroy_chance_stat):
		spawn_count += 1

	spawn_count += int(get_player_stat(spawn_extra_on_destroy_stat))

	if spawn_count > 0:
		spawn_burst_around(source_cell, spawn_count)

	if randf() <= get_player_stat(destroy_cluster_chance_stat):
		var cluster_size := int(get_player_stat(destroy_cluster_size_stat))
		if cluster_size > 0:
			spawn_burst_around(source_cell, cluster_size, profile.cluster_spread)


# --- Bool queries ---
func can_spawn_at(cell: Vector2i) -> bool:
	if not grid.is_free_for_spawn(cell):
		return false
	if is_near_player(cell):
		return false
	if chunk != null and chunk.has_window and not chunk.is_inside_window(cell):
		return false
	return true


## No spawnear encima ni pegado al player.
func is_near_player(cell: Vector2i) -> bool:
	if chunk == null:
		return false

	var player := chunk.follow_target
	if player == null:
		return false

	var player_cell := grid.world_to_cell(player.global_position)
	var clearance := profile.player_clearance_cells
	return maxi(absi(cell.x - player_cell.x), absi(cell.y - player_cell.y)) <= clearance


# --- Signal callbacks ---
func _on_ore_destroyed(ore: Ore) -> void:
	active_ores.erase(ore)
	var source_cell := ore.grid_cell
	release_ore(ore)
	handle_destroy_spawns(source_cell)
