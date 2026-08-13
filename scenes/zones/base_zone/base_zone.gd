extends Node2D
class_name BaseZone

@export var player: Player
@export var mines: Array[LevelData]

@onready var gui: GUI = $GUI

func _ready() -> void:
	Refs.player = player
	Refs.gui = gui
	Refs.inventory = gui.inventory
	GameManager.curr_state = GameManager.GameStates.PLAYING


func _exit_tree() -> void:
	SaveData.save_progress()
