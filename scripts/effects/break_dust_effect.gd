extends Sprite2D
class_name BreakDustBit
## Un grano de polvo al romper un bloque. Effects lleva el presupuesto de instancias.

const CIRCLE := preload("res://Circle512.png")

signal finished

var velocity: Vector2 = Vector2.ZERO
var gravity: float = 980.0
var spin: float = 0.0
var life: float = 0.35


func _init(world_pos: Vector2, color: Color) -> void:
	global_position = world_pos
	texture = CIRCLE
	centered = true
	modulate = color
	z_index = 30
	z_as_relative = false
	scale = Vector2.ONE * randf_range(0.018, 0.042)
	velocity = Vector2(randf_range(-220.0, 220.0), randf_range(-380.0, -80.0))
	gravity = randf_range(720.0, 1100.0)
	spin = randf_range(-8.0, 8.0)
	life = randf_range(0.28, 0.5)


func _ready() -> void:
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 0.0, life).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_callback(finish_bit)


func _process(delta: float) -> void:
	velocity.y += gravity * delta
	global_position += velocity * delta
	rotation += spin * delta


func finish_bit() -> void:
	finished.emit()
	queue_free()
