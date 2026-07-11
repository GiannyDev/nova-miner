extends Node2D
class_name MineZone

## Debug: ignora el stat y usa debug_ore_count para probar cantidades.
@export var use_debug_count: bool = false
@export var debug_ore_count: int = 15

@onready var grid: MineGrid = $MineGrid
@onready var ore_spawner: OreSpawner = $OreSpawner
@onready var ysort: Node2D = $YSort
@onready var player: Player = $YSort/Player

@onready var run_timer: Timer = $RunTimer

@onready var recap_menu: RecapMenu = %RecapMenu
@onready var settings_menu: SettingsMenu = %SettingsMenu

func _ready() -> void:
	GameManager.curr_state = GameManager.GameStates.PLAYING
	ore_spawner.setup(grid, ysort)
	run_timer.wait_time = 5.0
	run_timer.start()
	spawn_player()
	spawn_level_ores()


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
	if use_debug_count:
		return debug_ore_count
	return int(GameManager.player_stats.get_stat("starting_ore_amount"))


func _on_run_timer_timeout() -> void:
	EventBus.on_run_ended.emit()
	GameManager.curr_state = GameManager.GameStates.PAUSED
	recap_menu.show_recap()
