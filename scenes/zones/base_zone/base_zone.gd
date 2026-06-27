extends Node2D
class_name BaseZone

@export var player: Player

@onready var gui: GUI = $GUI
@onready var upgrade_bench_detector: Area2D = $YSort/UpgradeBench/PlayerDetector


func _ready() -> void:
	Refs.player = player
	GameManager.curr_state = GameManager.GameStates.PLAYING
	upgrade_bench_detector.body_entered.connect(_on_upgrade_bench_body_entered)


func _on_upgrade_bench_body_entered(body: Node2D) -> void:
	if body != player:
		return
	if not gui.is_upgrade_tree_open():
		gui.open_upgrade_tree()
