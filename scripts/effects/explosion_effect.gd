extends Sprite2D
class_name ExplosionEffect
## Flash circular que crece y se desvanece. Lo spawnea Effects.explosion().

const CIRCLE := preload("res://Circle512.png")
const TEXTURE_SIZE := 512.0

var radius_px: float = 128.0


func _init(world_pos: Vector2, blast_radius_px: float, color: Color) -> void:
	global_position = world_pos
	radius_px = maxf(blast_radius_px, 8.0)
	texture = CIRCLE
	modulate = color
	centered = true
	z_as_relative = false
	z_index = 40
	scale = Vector2.ONE * 0.04


func _ready() -> void:
	var end_scale := (radius_px * 2.0) / TEXTURE_SIZE
	var tween := create_tween().set_parallel(true)
	tween.tween_property(self, "scale", Vector2.ONE * end_scale, 0.22).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "modulate:a", 0.0, 0.22).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tween.chain().tween_callback(queue_free)
