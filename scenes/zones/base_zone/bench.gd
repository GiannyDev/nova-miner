extends Node2D
class_name Bench

@export var player_area: Area2D
@export var panel_to_open: Control

var is_player_colliding: bool

func _ready() -> void:
	if not player_area: return
	player_area.body_entered.connect(_on_player_entered)
	player_area.body_exited.connect(_on_player_exited)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("interact") and is_player_colliding:
		panel_to_open.show_panel()

func _on_player_entered(body: Node2D) -> void:
	is_player_colliding = true

func _on_player_exited(body: Node2D) -> void:
	is_player_colliding = false
