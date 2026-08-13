extends Node
class_name OreSpawner
## Spawn caotico en el chunk: mayoria random, poco bias cerca del player.
## Nunca safe_zone ni celdas recien minadas (evita respawn en el mismo cell).

# --- Exports ---
@export_group("Spawn")
@export var profile: MineSpawnProfile
@export var max_spawns_per_frame: int = 24
@export var refill_interval: float = 0.25

@export_group("Block Layout")
@export var block_layout: MineBlockLayout

# --- Runtime ---
var grid: MineGrid
var chunk: MineChunk
var pool: OrePool
var target: Node2D
var active_ores: Dictionary = {}
## Cola: x,y = celda, z = stack_index.
var spawn_queue: Array[Vector3i] = []
var refill_timer: float = 0.0
var window_connected: bool = false
## cell -> expire_msec. Evita respawn inmediato en celdas minadas.
var banned_cells: Dictionary = {}
## Si true, los ores salen colapsados para la animacion de intro.
var intro_spawn_mode: bool = false


# --- Built-ins ---
func _process(delta: float) -> void:
	drain_spawn_queue()
	expire_banned_cells()

	# Refill solo cuando la run ya arranco.
	if GameManager.curr_state != GameManager.GameStates.PLAYING:
		return

	refill_timer -= delta
	if refill_timer <= 0.0:
		refill_timer = maxf(refill_interval, 0.05)
		request_refill()


# --- Public API ---
func setup(mine_grid: MineGrid, mine_chunk: MineChunk, ore_parent: Node2D, ore_pool: OrePool = null) -> void:
	grid = mine_grid
	chunk = mine_chunk
	target = ore_parent
	pool = ore_pool

	ensure_profile()
	apply_block_layout_to_grid()
	connect_chunk_signals()
	refill_timer = 0.0
	banned_cells.clear()
	set_process(true)


func reserve_entry_area(world_position: Vector2) -> void:
	if grid == null:
		return
	grid.reserve_area(grid.world_to_cell(world_position), profile.start_clearance_cells)


func spawn_initial_batch() -> void:
	if grid == null or chunk == null or not chunk.has_window:
		push_warning("OreSpawner: la ventana del chunk no esta lista para el spawn inicial.")
		return

	var count := get_target_ore_count()
	if count <= 0:
		return

	enqueue_scatter(count)


## Vacia la cola de golpe (intro: todos listos antes de la animacion).
func flush_spawn_queue() -> void:
	while not spawn_queue.is_empty():
		spawn_queued_block(spawn_queue.pop_back())


## Todos los ores activos crecen a la vez desde abajo.
func play_intro_rise_all(duration: float) -> void:
	for ore in active_ores.keys():
		if is_instance_valid(ore):
			(ore as Ore).play_rise_animation(duration)
	await get_tree().create_timer(duration).timeout


## Extras al destruir: scatter en el chunk (no anclados a la celda rota).
func spawn_burst_around(_source_cell: Vector2i, count: int, _spread: int = -1) -> void:
	if count <= 0 or grid == null or chunk == null or not chunk.has_window:
		return
	enqueue_scatter(count)


func request_refill() -> void:
	if grid == null or chunk == null or not chunk.has_window:
		return

	var missing := get_target_ore_count() - get_pending_ore_count()
	if missing <= 0:
		return

	enqueue_scatter(missing)


func clear_ores() -> void:
	spawn_queue.clear()
	banned_cells.clear()

	for ore in active_ores.keys():
		if is_instance_valid(ore):
			release_ore(ore)
	active_ores.clear()


func reset() -> void:
	clear_ores()
	if grid != null:
		grid.reset()
	if chunk != null:
		chunk.reset()


func get_active_ore_count() -> int:
	return active_ores.size()


func get_pending_ore_count() -> int:
	return active_ores.size() + spawn_queue.size()


func get_target_ore_count() -> int:
	if GameManager.player_stats == null:
		return 0
	return maxi(int(GameManager.player_stats.get_stat(int(Stats.STARTING_ORE_AMOUNT))), 0)


# --- Private helpers ---
func connect_chunk_signals() -> void:
	if chunk == null or window_connected:
		return
	if not chunk.on_window_moved.is_connected(_on_window_moved):
		chunk.on_window_moved.connect(_on_window_moved)
	window_connected = true


## Coloca `count` ores: mayoria random en el chunk, near_player_bias cerca del player.
func enqueue_scatter(count: int) -> void:
	if not chunk.has_window:
		return

	var placed: Array[Vector2i] = []
	for i in count:
		var prefer_near := randf() < profile.near_player_bias
		try_queue_cell(prefer_near, placed)


func try_queue_cell(prefer_near: bool, placed_cells: Array[Vector2i]) -> bool:
	var area := get_spawn_area(prefer_near)
	if area.size == Vector2i.ZERO:
		area = chunk.window_cells

	for i in maxi(profile.max_attempts_per_ore, 1):
		var cell := pick_candidate_cell(area, placed_cells, prefer_near)
		if not can_spawn_at(cell):
			continue
		placed_cells.append(cell)
		enqueue_stack(cell)
		return true

	# Fallback: cualquier hueco libre del chunk.
	if prefer_near:
		return try_queue_cell(false, placed_cells)
	return false


func get_spawn_area(prefer_near: bool) -> Rect2i:
	if prefer_near:
		return get_near_player_spawn_area(get_player_cell())
	return chunk.window_cells


func pick_candidate_cell(area: Rect2i, placed_cells: Array[Vector2i], prefer_near: bool) -> Vector2i:
	if prefer_near and should_apply_forward_bias():
		return pick_forward_biased_cell(area)

	# Cluster hacia ores ya puestos en este batch, nunca offset (0,0).
	if not placed_cells.is_empty() and randf() <= profile.cluster_chance:
		return pick_cluster_neighbor(area, placed_cells)

	return pick_random_valid_in_area(area)


func pick_cluster_neighbor(area: Rect2i, placed_cells: Array[Vector2i]) -> Vector2i:
	var base: Vector2i = placed_cells.pick_random()
	var spread := maxi(profile.cluster_spread, 1)
	for i in maxi(profile.max_attempts_per_ore, 1):
		var offset := Vector2i(randi_range(-spread, spread), randi_range(-spread, spread))
		if offset == Vector2i.ZERO:
			continue
		var cell := clamp_cell_to_rect(base + offset, area)
		if cell != base:
			return cell
	return pick_random_valid_in_area(area)


func pick_forward_biased_cell(area: Rect2i) -> Vector2i:
	var direction := get_player_move_direction()
	var player_cell := get_player_cell()

	for i in maxi(profile.max_attempts_per_ore, 1):
		var cell := pick_random_valid_in_area(area)
		var offset := Vector2(cell - player_cell)
		if offset.length_squared() < 0.01:
			continue
		if offset.dot(direction) >= 0.0:
			return cell

	return pick_random_valid_in_area(area)


func pick_random_valid_in_area(area: Rect2i) -> Vector2i:
	var player_cell := get_player_cell()
	for i in maxi(profile.max_attempts_per_ore, 1):
		var cell := random_cell_in(area)
		if profile.is_inside_safe_zone(cell, player_cell):
			continue
		if is_cell_banned(cell):
			continue
		return cell
	return random_cell_in(area)


func random_cell_in(area: Rect2i) -> Vector2i:
	return Vector2i(
		randi_range(area.position.x, area.end.x - 1),
		randi_range(area.position.y, area.end.y - 1)
	)


func clamp_cell_to_rect(cell: Vector2i, cell_rect: Rect2i) -> Vector2i:
	return Vector2i(
		clampi(cell.x, cell_rect.position.x, cell_rect.end.x - 1),
		clampi(cell.y, cell_rect.position.y, cell_rect.end.y - 1)
	)


func get_near_player_spawn_area(player_cell: Vector2i) -> Rect2i:
	var radius := maxi(profile.near_spawn_radius, profile.safe_zone_size + 1)
	var area := Rect2i(
		player_cell - Vector2i(radius, radius),
		Vector2i(radius * 2 + 1, radius * 2 + 1)
	)
	var clipped := intersect_with_window(area)
	if clipped.size != Vector2i.ZERO:
		return clipped
	return chunk.window_cells if chunk != null else area


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


func enqueue_stack(cell: Vector2i) -> void:
	var height := profile.get_stack_height()
	for stack_index in height:
		grid.add_stack_occupation(cell)
		spawn_queue.append(Vector3i(cell.x, cell.y, stack_index))


func drain_spawn_queue() -> void:
	var budget := maxi(max_spawns_per_frame, 1)
	while budget > 0 and not spawn_queue.is_empty():
		spawn_queued_block(spawn_queue.pop_back())
		budget -= 1


func spawn_queued_block(entry: Vector3i) -> void:
	var cell := Vector2i(entry.x, entry.y)

	# Revalidar: player pudo entrar / celda baneada mientras esperaba en cola.
	if not can_spawn_at(cell, true):
		grid.remove_stack_occupation(cell)
		return

	spawn_ore_at_cell(cell, entry.z)


## occupation_already_held: la cola ya marco la celda; no exigir is_free_for_spawn.
func can_spawn_at(cell: Vector2i, occupation_already_held: bool = false) -> bool:
	if grid == null:
		return false
	if not occupation_already_held and not grid.is_free_for_spawn(cell):
		return false
	if is_cell_banned(cell):
		return false
	if profile.is_inside_safe_zone(cell, get_player_cell()):
		return false
	if chunk == null or not chunk.has_window:
		return false
	return chunk.is_inside_window(cell)


func spawn_ore_at_cell(cell: Vector2i, stack_index: int = 0) -> Ore:
	var ore := acquire_ore()
	if ore == null:
		return null

	var ore_data := profile.pick_ore_data()
	ore.visible = false
	ore.global_position = grid.get_ore_world_position(cell, stack_index)
	ore.reset_physics_interpolation()
	ore.setup(
		profile.get_ore_hp(ore_data, OreDefinition.OreSize.SMALL),
		grid,
		cell,
		OreDefinition.OreSize.SMALL,
		stack_index,
		ore_data
	)
	ore.on_spawned()
	if intro_spawn_mode:
		ore.prepare_intro_collapsed()
	else:
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


func apply_block_layout_to_grid() -> void:
	if grid == null:
		return
	if block_layout != null:
		grid.block_layout = block_layout
	grid.ensure_block_layout()
	grid.sync_cell_size_from_layout()


func get_player_stat(stat_id: int) -> float:
	if GameManager.player_stats == null:
		return 0.0
	return GameManager.player_stats.get_stat(int(stat_id))


func handle_destroy_spawns(source_cell: Vector2i) -> void:
	ban_cell(source_cell)

	var spawn_count := 0
	if randf() <= get_player_stat(Stats.SPAWN_ON_DESTROY_CHANCE):
		spawn_count += 1
	spawn_count += int(get_player_stat(Stats.SPAWN_ORE_WHEN_DESTROYED_AMOUNT))

	if spawn_count > 0:
		enqueue_scatter(spawn_count)

	if randf() <= get_player_stat(Stats.SPAWN_CLUSTER_CHANCE):
		var cluster_size := int(get_player_stat(Stats.SPAWN_CLUSTER_SIZE))
		if cluster_size > 0:
			enqueue_scatter(cluster_size)


func ban_cell(cell: Vector2i) -> void:
	var ban_ms := int(maxf(profile.mined_cell_ban_seconds, 0.05) * 1000.0)
	banned_cells[cell] = Time.get_ticks_msec() + ban_ms


func is_cell_banned(cell: Vector2i) -> bool:
	return banned_cells.has(cell)


func expire_banned_cells() -> void:
	if banned_cells.is_empty():
		return
	var now := Time.get_ticks_msec()
	var expired: Array[Vector2i] = []
	for cell in banned_cells.keys():
		if int(banned_cells[cell]) <= now:
			expired.append(cell)
	for cell in expired:
		banned_cells.erase(cell)


func get_player_cell() -> Vector2i:
	if chunk == null or chunk.follow_target == null or grid == null:
		return Vector2i.ZERO
	return grid.world_to_cell(chunk.follow_target.global_position)


func get_player_move_direction() -> Vector2:
	if chunk == null or chunk.follow_target == null:
		return Vector2.ZERO
	if chunk.follow_target is CharacterBody2D:
		var body := chunk.follow_target as CharacterBody2D
		if body.velocity.length_squared() > profile.forward_bias_min_speed * profile.forward_bias_min_speed:
			return body.velocity.normalized()
	return Vector2.ZERO


func should_apply_forward_bias() -> bool:
	if profile.forward_bias_ratio <= 0.0:
		return false
	if get_player_move_direction() == Vector2.ZERO:
		return false
	return randf() < profile.forward_bias_ratio


func is_inside_player_safe_zone(cell: Vector2i) -> bool:
	return profile.is_inside_safe_zone(cell, get_player_cell())


# --- Signal callbacks ---
func _on_ore_destroyed(ore: Ore) -> void:
	active_ores.erase(ore)
	var source_cell := ore.grid_cell
	release_ore(ore)
	handle_destroy_spawns(source_cell)
	request_refill()


func _on_window_moved(_window_cells: Rect2i) -> void:
	request_refill()
