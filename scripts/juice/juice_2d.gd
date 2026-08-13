@tool
extends Node2D
class_name Juice2D

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

@export_group("Preview")
@export_tool_button("Twist") var preview_twist_action: Callable:
	get:
		return preview_twist
@export_tool_button("Twist Random") var preview_twist_random_action: Callable:
	get:
		return preview_twist_random
@export_tool_button("Jiggle") var preview_jiggle_action: Callable:
	get:
		return preview_jiggle
@export_tool_button("Squash") var preview_squash_action: Callable:
	get:
		return preview_squash
@export_tool_button("Spawn") var preview_spawn_action: Callable:
	get:
		return preview_spawn
@export_tool_button("Reset") var preview_reset_action: Callable:
	get:
		return end_preview

var pos_spring: DampedSpring2D = null
var rot_spring: DampedSpring1D = null
var squash_spring: DampedSpring1D = null
var jiggle_spring: DampedSpring1D = null
var spawn_spring: DampedSpring1D = null

var previewing := false
var preview_age := 0
var preview_rest_rotation := 0.0
var preview_rest_scale := Vector2.ONE
var springs_ready := false


func _ready():
	initialize.call_deferred()


func initialize():
	if animate_position and move_animation:
		pos_spring = DampedSpring2D.new(move_animation.damping_ratio, move_animation.frequency)
	if animate_rotation and twist_animation:
		rot_spring = DampedSpring1D.new(twist_animation.damping_ratio, twist_animation.frequency)
	if animate_scale and squash_animation:
		squash_spring = DampedSpring1D.new(squash_animation.damping_ratio, squash_animation.frequency)
	if animate_scale and jiggle_animation:
		jiggle_spring = DampedSpring1D.new(jiggle_animation.damping_ratio, jiggle_animation.frequency).rest_at(1.0)
	if animate_spawn and spawn_animation:
		spawn_spring = DampedSpring1D.new(spawn_animation.damping_ratio, spawn_animation.frequency)

	if animate_position and pos_spring and target_node:
		pos_spring.set_position(global_position)
		pos_spring.rest_at(target_node.global_position)

	if animate_scale and jiggle_spring:
		jiggle_spring.position = 1.0

	springs_ready = true
	initialized.emit()


func _physics_process(delta):
	if Engine.is_editor_hint():
		return
	update_springs(delta)


func _process(_delta):
	if Engine.is_editor_hint():
		tick_editor_preview()
		return
	apply_pose()


func update_springs(delta: float) -> void:
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


## Editor: integrate on the frame loop (physics may not tick), then restore rest pose.
func tick_editor_preview() -> void:
	if not previewing or target_node == null:
		return
	update_springs(get_process_delta_time())
	apply_pose()
	preview_age += 1
	if preview_age > 4 and is_preview_settled():
		end_preview()


func apply_pose() -> void:
	if target_node == null:
		return
	if animate_position and pos_spring and not Engine.is_editor_hint():
		target_node.global_position = pos_spring.get_position()

	if animate_rotation and rot_spring and twist_animation:
		target_node.rotation_degrees = twist_animation.intensity * rot_spring.position

	if animate_scale and jiggle_spring and squash_spring:
		target_node.scale = Vector2.ONE * jiggle_spring.position + Vector2(1, -1) * squash_spring.position

		if stabilize_scale:
			if target_node.scale.x > 0.995 and target_node.scale.x < 1.005:
				target_node.scale.x = 1.0
			if target_node.scale.y > 0.995 and target_node.scale.y < 1.005:
				target_node.scale.y = 1.0

		if animate_spawn and spawn_spring and spawn_animation:
			target_node.scale *= Vector2.ONE * (1.0 - spawn_spring.position)
			target_node.rotation_degrees = spawn_animation.intensity * spawn_spring.position


func move(from: Vector2, to: Vector2):
	if animate_position and pos_spring:
		pos_spring.set_position(from)
		pos_spring.rest_at(to)


func twist(from := 1.0, to := 0.0):
	if animate_rotation and rot_spring:
		rot_spring.position = from
		rot_spring.rest_at(to)


func twist_random():
	var dir = [-1, 1].pick_random()
	twist(dir, 0.0)


func jiggle(scalar := 1.0):
	if animate_scale and jiggle_spring and jiggle_animation:
		jiggle_spring.position = 1.0 + jiggle_animation.intensity * scalar


func squash(scalar := 1.0):
	if animate_scale and squash_spring and squash_animation:
		squash_spring.position = squash_animation.intensity * scalar


func spawn():
	if animate_spawn and spawn_spring:
		spawn_spring.position = 1.0


func preview_twist() -> void:
	begin_preview()
	twist()


func preview_twist_random() -> void:
	begin_preview()
	twist_random()


func preview_jiggle() -> void:
	begin_preview()
	jiggle()


func preview_squash() -> void:
	begin_preview()
	squash()


func preview_spawn() -> void:
	begin_preview()
	spawn()


## Snapshot rest pose, then let editor _process apply springs onto target_node.
func begin_preview() -> void:
	ensure_initialized()
	if target_node == null:
		return
	if not previewing:
		preview_rest_rotation = target_node.rotation_degrees
		preview_rest_scale = target_node.scale
	previewing = true
	preview_age = 0


func end_preview() -> void:
	if rot_spring:
		rot_spring.position = rot_spring.rest_pos
		rot_spring.velocity = 0.0
	if jiggle_spring:
		jiggle_spring.position = jiggle_spring.rest_pos
		jiggle_spring.velocity = 0.0
	if squash_spring:
		squash_spring.position = squash_spring.rest_pos
		squash_spring.velocity = 0.0
	if spawn_spring:
		spawn_spring.position = spawn_spring.rest_pos
		spawn_spring.velocity = 0.0
	if target_node and previewing:
		target_node.rotation_degrees = preview_rest_rotation
		target_node.scale = preview_rest_scale
	previewing = false
	preview_age = 0


func is_preview_settled() -> bool:
	if rot_spring and (absf(rot_spring.position - rot_spring.rest_pos) > 0.02 or absf(rot_spring.velocity) > 0.08):
		return false
	if jiggle_spring and (absf(jiggle_spring.position - jiggle_spring.rest_pos) > 0.02 or absf(jiggle_spring.velocity) > 0.08):
		return false
	if squash_spring and (absf(squash_spring.position - squash_spring.rest_pos) > 0.02 or absf(squash_spring.velocity) > 0.08):
		return false
	if spawn_spring and (absf(spawn_spring.position - spawn_spring.rest_pos) > 0.02 or absf(spawn_spring.velocity) > 0.08):
		return false
	return true


func ensure_initialized() -> void:
	if not springs_ready:
		initialize()
