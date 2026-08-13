extends Node2D
class_name Juice2D
## Juice de boton/tooltip YKTD (springs locales).

signal initialized

@export var target_node: Node
@export var animate_position := true
@export var animate_rotation := true
@export var animate_scale := true
@export var animate_spawn := false
@export var stabilize_scale := false
@export var move_animation: DampedSpringData
@export var twist_animation: DampedSpringData
@export var jiggle_animation: DampedSpringData
@export var squash_animation: DampedSpringData
@export var spawn_animation: DampedSpringData

var pos_spring: DampedSpring2D = null
var rot_spring: DampedSpring1D = null
var squash_spring: DampedSpring1D = null
var jiggle_spring: DampedSpring1D = null
var spawn_spring: DampedSpring1D = null


func _ready():
	initialize.call_deferred()


func initialize():
	if animate_position:
		pos_spring = DampedSpring2D.new(move_animation.damping_ratio, move_animation.frequency)
	if animate_rotation:
		rot_spring = DampedSpring1D.new(twist_animation.damping_ratio, twist_animation.frequency)
	if animate_scale:
		squash_spring = DampedSpring1D.new(squash_animation.damping_ratio, squash_animation.frequency)
	if animate_scale:
		jiggle_spring = DampedSpring1D.new(jiggle_animation.damping_ratio, jiggle_animation.frequency).rest_at(1.0)
	if animate_spawn:
		spawn_spring = DampedSpring1D.new(spawn_animation.damping_ratio, spawn_animation.frequency)

	if animate_position:
		pos_spring.set_position(global_position)
		pos_spring.rest_at(target_node.global_position)

	if animate_scale:
		jiggle_spring.position = 1.0

	initialized.emit()


func _physics_process(delta):
	if pos_spring:
		pos_spring.update(delta)
	if rot_spring:
		rot_spring.update(delta)
	if squash_spring:
		squash_spring.update(delta)
	if jiggle_spring:
		jiggle_spring.update(delta)
	if spawn_spring:
		spawn_spring.update(delta)


func _process(_delta):
	if target_node:
		if animate_position:
			target_node.global_position = pos_spring.get_position()

		if animate_rotation:
			target_node.rotation_degrees = twist_animation.intensity * rot_spring.position

		if animate_scale:
			target_node.scale = Vector2.ONE * jiggle_spring.position + Vector2(1, -1) * squash_spring.position

			if stabilize_scale:
				if target_node.scale.x > 0.995 and target_node.scale.x < 1.005:
					target_node.scale.x = 1.0
				if target_node.scale.y > 0.995 and target_node.scale.y < 1.005:
					target_node.scale.y = 1.0

			if animate_spawn:
				target_node.scale *= Vector2.ONE * (1.0 - spawn_spring.position)
				target_node.rotation_degrees = spawn_animation.intensity * spawn_spring.position


func move(from: Vector2, to: Vector2):
	if animate_position:
		pos_spring.set_position(from)
		pos_spring.rest_at(to)


func twist(from := 1.0, to := 0.0):
	if animate_rotation:
		rot_spring.position = from
		rot_spring.rest_at(to)


func twist_random():
	var dir = [-1, 1].pick_random()
	twist(dir, 0.0)


func jiggle(scalar := 1.0):
	if animate_scale:
		jiggle_spring.position = 1.0 + jiggle_animation.intensity * scalar


func squash(scalar := 1.0):
	if animate_scale:
		squash_spring.position = squash_animation.intensity * scalar


func spawn():
	if animate_spawn:
		spawn_spring.position = 1.0
