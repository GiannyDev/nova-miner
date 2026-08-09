extends Node2D
class_name MineZone
## Zona de mina: cablea grid, chunk, spawner, pool, player. Fin de run = durabilidad 0.

@export_group("Recap")
## Los 3 minerales que muestra el recap de esta submina (orden fijo en pantalla).
@export var recap_ore_ids: Array[String] = ["gold", "silver", "platinum"]


@export_category("Debug")
@export var debug_fast_forward: float = 1.0

# --- Onready / cached ---
@onready var grid: MineGrid = $MineGrid
@onready var chunk: MineChunk = $MineChunk
@onready var ore_pool: OrePool = $OrePool
@onready var ore_spawner: OreSpawner = $OreSpawner
@onready var ysort: Node2D = $YSort
@onready var player: Player = $YSort/Player

## GUI
@onready var durability_bar: ProgressBar = $GUI/QuotaProgressBar
@onready var durability_title: Label = $GUI/QuotaProgressBar/QuotaExtraction
@onready var durability_label: Label = %QuotaProgressLabel
@onready var recap_menu: RecapMenu = %RecapMenu
@onready var settings_menu: SettingsMenu = %SettingsMenu

## Run data
var ores_collected: Dictionary = {}
var blocks_mined: int = 0
var damage_dealt: float = 0.0
var distance_traveled: float = 0.0
var last_player_cell: Vector2i = Vector2i.ZERO
var run_elapsed: float = 0.0
var run_ended: bool = false


# --- Built-ins ---
func _ready() -> void:
	GameManager.curr_state = GameManager.GameStates.PLAYING
	run_ended = false
	run_elapsed = 0.0
	ore_spawner.setup(grid, chunk, ysort, ore_pool)
	GameManager.repair_drill_full()
	spawn_player()
	start_mine_generation()
	connect_run_tracking()
	setup_durability_hud()
	EventBus.on_run_started.emit()


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("fast_forward"):
		Engine.time_scale = debug_fast_forward
	elif event.is_action_released("fast_forward"):
		Engine.time_scale = 1.0


func _physics_process(delta: float) -> void:
	if run_ended or player == null:
		return
	run_elapsed += delta
	track_distance_traveled()


func _process(delta: float) -> void:
	if run_ended:
		return
	
	GameManager.consume_drill_durability(delta)
	refresh_durability_hud()


func connect_run_tracking() -> void:
	if not EventBus.ore_amount_changed.is_connected(_on_ore_amount_changed): EventBus.ore_amount_changed.connect(_on_ore_amount_changed)
	if not EventBus.run_ore_destroyed.is_connected(_on_run_ore_destroyed): EventBus.run_ore_destroyed.connect(_on_run_ore_destroyed)
	if not EventBus.drill_durability_depleted.is_connected(_on_drill_durability_depleted): EventBus.drill_durability_depleted.connect(_on_drill_durability_depleted)
	if not EventBus.drill_durability_changed.is_connected(_on_drill_durability_changed): EventBus.drill_durability_changed.connect(_on_drill_durability_changed)
	if player != null and not player.dealt_damage.is_connected(_on_dealt_damage): player.dealt_damage.connect(_on_dealt_damage)


func setup_durability_hud() -> void:
	if durability_title != null:
		durability_title.text = "Drill Durability"
	if durability_bar != null:
		durability_bar.max_value = 1.0
		durability_bar.min_value = 0.0
	refresh_durability_hud()


## Coloca al player en el origen (centro del mapa) y lo registra globalmente.
func spawn_player() -> void:
	player.global_position = Vector2.ZERO
	last_player_cell = grid.world_to_cell(player.global_position)
	Refs.player = player


func start_mine_generation() -> void:
	ore_spawner.reserve_entry_area(player.global_position)
	chunk.follow(player)
	ore_spawner.spawn_initial_batch()


func spawn_extra_ores(cell: Vector2i, count: int) -> void:
	ore_spawner.spawn_burst_around(cell, count)


func boost_chunk_size(extra_cells: Vector2i, duration: float) -> void:
	chunk.add_size_modifier(&"skill_boost", extra_cells, duration)


## 1 metro por cada celda recorrida (Manhattan en el grid).
func track_distance_traveled() -> void:
	if grid == null or player == null:
		return
	var current_cell := grid.world_to_cell(player.global_position)
	if current_cell == last_player_cell:
		return
	var delta := current_cell - last_player_cell
	distance_traveled += float(absi(delta.x) + absi(delta.y))
	last_player_cell = current_cell


func build_recap_data() -> RunRecapData:
	var recap := RunRecapData.new()
	recap.recap_ore_ids = recap_ore_ids.duplicate()
	recap.ores_collected = ores_collected.duplicate()
	recap.blocks_mined = blocks_mined
	recap.damage_dealt = damage_dealt
	recap.distance_traveled = distance_traveled
	return recap


func get_time_format(seconds: float) -> String:
	var total_seconds := int(seconds)
	var minutes := int(total_seconds / 60.0)
	var secs := total_seconds % 60
	return "%02d:%02d" % [minutes, secs]


func refresh_durability_hud() -> void:
	var current: float = GameManager.get_drill_durability()
	var max_value: float = maxf(GameManager.get_drill_durability_max(), 0.001)
	var ratio := clampf(current / max_value, 0.0, 1.0)

	durability_bar.value = ratio
	durability_label.text = "%d%%" % int(round(ratio * 100.0))


func end_run() -> void:
	#if not run_ended:
		#return
	run_ended = true
	EventBus.on_run_ended.emit()
	GameManager.curr_state = GameManager.GameStates.PAUSED
	recap_menu.show_recap(build_recap_data())


func _on_ore_amount_changed(ore_data: OreData, _new_amount: int, delta: int) -> void:
	if delta <= 0 or GameManager.curr_state != GameManager.GameStates.PLAYING:
		return
	var ore_id := ore_data.id if ore_data != null else ""
	if ore_id.is_empty():
		return
	ores_collected[ore_id] = int(ores_collected.get(ore_id, 0)) + delta


func _on_run_ore_destroyed(_ore: Ore) -> void:
	if GameManager.curr_state != GameManager.GameStates.PLAYING:
		return
	blocks_mined += 1


func _on_dealt_damage(amount: float) -> void:
	if amount <= 0.0 or GameManager.curr_state != GameManager.GameStates.PLAYING:
		return
	damage_dealt += amount


func _on_drill_durability_changed(_current: float, _max_value: float) -> void:
	refresh_durability_hud()


func _on_drill_durability_depleted() -> void:
	print("ended")
	end_run()
