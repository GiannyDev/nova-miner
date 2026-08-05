extends Node2D
class_name MineZone
## Zona de mina: cablea grid, chunk de spawn, spawner, pool, player y timers de run.

@export_group("Recap")
## Los 3 minerales que muestra el recap de esta submina (orden fijo en pantalla).
@export var recap_ore_ids: Array[String] = ["gold", "silver", "platinum"]

# --- Onready / cached ---
@onready var grid: MineGrid = $MineGrid
@onready var chunk: MineChunk = $MineChunk
@onready var ore_pool: OrePool = $OrePool
@onready var ore_spawner: OreSpawner = $OreSpawner
@onready var ysort: Node2D = $YSort
@onready var player: Player = $YSort/Player
@onready var run_timer: Timer = $RunTimer

## GUI
@onready var time: Label = %Time
@onready var recap_menu: RecapMenu = %RecapMenu
@onready var settings_menu: SettingsMenu = %SettingsMenu

## Run data
var ores_collected: Dictionary = {}
var blocks_mined: int = 0
var damage_dealt: float = 0.0
var distance_traveled: float = 0.0
var last_player_position: Vector2 = Vector2.ZERO


# --- Built-ins ---
func _ready() -> void:
	GameManager.curr_state = GameManager.GameStates.PLAYING
	ore_spawner.setup(grid, chunk, ysort, ore_pool)
	run_timer.wait_time = 10.0
	run_timer.start()
	spawn_player()
	start_mine_generation()
	connect_run_tracking()


func _physics_process(_delta: float) -> void:
	if run_timer.is_stopped() or player == null:
		return
	track_distance_traveled()


func _process(_delta: float) -> void:
	if run_timer.is_stopped():
		return
	time.text = get_time_format(run_timer.time_left)


func connect_run_tracking() -> void:
	if not EventBus.ore_amount_changed.is_connected(_on_ore_amount_changed):
		EventBus.ore_amount_changed.connect(_on_ore_amount_changed)
	if not EventBus.run_ore_destroyed.is_connected(_on_run_ore_destroyed):
		EventBus.run_ore_destroyed.connect(_on_run_ore_destroyed)
	if player != null and not player.dealt_damage.is_connected(_on_dealt_damage):
		player.dealt_damage.connect(_on_dealt_damage)


## Coloca al player en el origen (centro del mapa) y lo registra globalmente.
func spawn_player() -> void:
	player.global_position = Vector2.ZERO
	last_player_position = player.global_position
	Refs.player = player


func start_mine_generation() -> void:
	ore_spawner.reserve_entry_area(player.global_position)
	chunk.follow(player)
	ore_spawner.spawn_initial_batch()


func spawn_extra_ores(cell: Vector2i, count: int) -> void:
	ore_spawner.spawn_burst_around(cell, count)


func boost_chunk_size(extra_cells: Vector2i, duration: float) -> void:
	chunk.add_size_modifier(&"skill_boost", extra_cells, duration)


func track_distance_traveled() -> void:
	var current_position := player.global_position
	distance_traveled += last_player_position.distance_to(current_position)
	last_player_position = current_position


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
	var minutes := total_seconds / 60
	var secs := total_seconds % 60
	return "%02d:%02d" % [minutes, secs]


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


func _on_run_timer_timeout() -> void:
	EventBus.on_run_ended.emit()
	GameManager.curr_state = GameManager.GameStates.PAUSED
	recap_menu.show_recap(build_recap_data())
