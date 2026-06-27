## Guarda estado global, niveles del arbol y stats del jugador con upgrades aplicados.

extends Node

enum GameStates {
	NONE,
	PLAYING,
	PAUSED,
	GAMEOVER,
}

var curr_state: GameStates = GameStates.NONE
var skill_levels: Dictionary = {}
var player_stats: StatsData

@export var player_stats_base: StatsData


func _ready() -> void:
	_init_player_stats()


func _init_player_stats() -> void:
	if player_stats_base == null:
		player_stats_base = load("res://resources/data/player/player_stats_base.tres")

	player_stats = player_stats_base.duplicate(true)
	UpgradeManager.apply_stats_to_player()


func refresh_player_stats() -> void:
	player_stats = player_stats_base.duplicate(true)
	UpgradeManager.apply_stats_to_player()
