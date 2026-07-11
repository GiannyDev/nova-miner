extends Node2D
class_name BaseZone

@export var player: Player

@onready var gui: GUI = $GUI

func _ready() -> void:
	Refs.player = player
	GameManager.curr_state = GameManager.GameStates.PLAYING
