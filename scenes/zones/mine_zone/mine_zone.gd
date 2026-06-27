extends Node2D
class_name MineZone

func _ready() -> void:
	GameManager.curr_state = GameManager.GameStates.PLAYING
