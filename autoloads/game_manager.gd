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
var player_stats: StatBlock

@export var player_stats_base: StatBlock


func _ready() -> void:
	_init_player_stats()


func _init_player_stats() -> void:
	if player_stats_base == null:
		player_stats_base = StatBlock.new()
		player_stats_base.base_stats = {
			"attack": 10.0,
			"attack_cooldown": 0.5,
			"oxygen": 100.0,
			"speed": 300.0,
			"laser_length": 450.0,
			"pickup_radius": 50.0,
			"helpers_unlocked": 0.0,
		}

	player_stats = player_stats_base.duplicate(true)
	player_stats.clear_modifier()
	UpgradeManager.apply_stats_to_player()


func refresh_player_stats() -> void:
	player_stats = player_stats_base.duplicate(true)
	player_stats.clear_modifier()
	UpgradeManager.apply_stats_to_player()
