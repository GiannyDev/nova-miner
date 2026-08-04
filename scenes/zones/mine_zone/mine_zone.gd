extends Node2D
class_name MineZone
## Zona de mina: grid, spawner de ores, player y timers de run.

# --- Onready / cached ---
@onready var grid: MineGrid = $MineGrid
@onready var ore_spawner: OreSpawner = $OreSpawner
@onready var ysort: Node2D = $YSort
@onready var player: Player = $YSort/Player
@onready var run_timer: Timer = $RunTimer

## GUI
@onready var time: Label = %Time
@onready var recap_menu: RecapMenu = %RecapMenu
@onready var settings_menu: SettingsMenu = %SettingsMenu


# --- Built-ins ---
func _ready() -> void:
	GameManager.curr_state = GameManager.GameStates.PLAYING
	ore_spawner.setup(grid, ysort)
	run_timer.wait_time = 10.0
	run_timer.start()
	spawn_player()
	spawn_level_ores()


func _process(delta: float) -> void:
	if run_timer.is_stopped():
		return
	time.text = get_time_format(run_timer.time_left)


# --- Public API ---
## Coloca al player en el origen (centro del mapa) y lo registra globalmente.
func spawn_player() -> void:
	player.global_position = Vector2.ZERO
	Refs.player = player


## Crea el robot ayudante [si esta desbloqueado].
func spawn_helper() -> void:
	pass


## Crea los ores de la run distribuidos en el grid.
func spawn_level_ores() -> void:
	ore_spawner.generate(get_ore_count())


## Crea ores extra [usado al mejorar el % de spawn extra al minar].
func spawn_extra_ore() -> void:
	pass


func get_ore_count() -> int:
	return int(GameManager.player_stats.get_stat("starting_ore_amount"))


func get_time_format(seconds: float) -> String:
	var total_seconds := int(seconds)
	var minutes := total_seconds / 60
	var secs := total_seconds % 60
	return "%02d:%02d" % [minutes, secs]


# --- Signal callbacks ---
func _on_run_timer_timeout() -> void:
	EventBus.on_run_ended.emit()
	GameManager.curr_state = GameManager.GameStates.PAUSED
	recap_menu.show_recap()
