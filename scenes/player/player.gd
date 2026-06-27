extends CharacterBody2D
class_name Player

@export var fallback_speed: float = 200.0
@export var run_speed_threshold: float = 20.0
@export var run_animation: String = "run_forward"
@export var idle_animation: String = "idle"

@onready var movement_component: MovementComponent = $MovementComponent
@onready var spine_sprite: SpineSprite = $SpineSprite

var input_direction: Vector2 = Vector2.ZERO
var facing_direction: Vector2 = Vector2.RIGHT
var current_animation: String = ""
var idle_uses_run_fallback: bool = false


func _ready() -> void:
	y_sort_enabled = true
	play_animation(idle_animation, true)


func _physics_process(delta: float) -> void:
	if can_move():
		get_input_direction()
		move_player(delta)
		update_facing()
	else:
		move_player(delta, true)

	update_animation()


func get_input_direction() -> void:
	input_direction = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if input_direction.length_squared() > 1.0:
		input_direction = input_direction.normalized()


func move_player(delta: float, decelerate_only: bool = false) -> void:
	var direction := Vector2.ZERO if decelerate_only else input_direction
	movement_component.move(self, direction, delta, get_move_speed())


func update_facing() -> void:
	if input_direction.length_squared() > 0.01:
		facing_direction = input_direction.normalized()
	elif velocity.length_squared() > run_speed_threshold * run_speed_threshold:
		facing_direction = velocity.normalized()

	apply_facing_flip()


func update_animation() -> void:
	var is_moving := velocity.length() > run_speed_threshold
	var animation_name := run_animation if is_moving else idle_animation
	play_animation(animation_name, true)
	sync_animation_speed(is_moving)


func get_move_speed() -> float:
	if GameManager.player_stats != null:
		return GameManager.player_stats.get_stat("speed")
	return fallback_speed


func apply_facing_flip() -> void:
	if absf(facing_direction.x) < 0.01:
		return

	var base_scale := absf(spine_sprite.scale.x)
	spine_sprite.scale.x = base_scale if facing_direction.x >= 0.0 else -base_scale


func sync_animation_speed(is_moving: bool) -> void:
	var animation_state := spine_sprite.get_animation_state()
	if animation_state == null:
		return

	if not is_moving:
		animation_state.set_time_scale(0.0 if idle_uses_run_fallback else 1.0)
		return

	var base_speed := fallback_speed
	if GameManager.player_stats != null:
		base_speed = maxf(GameManager.player_stats.base_stats.get("speed", fallback_speed), 1.0)

	var speed_ratio := clampf(get_move_speed() / base_speed, 0.75, 1.5)
	var velocity_ratio := clampf(velocity.length() / maxf(get_move_speed(), 1.0), 0.5, 1.0)
	animation_state.set_time_scale(speed_ratio * velocity_ratio)


func play_animation(animation_name: String, loop: bool) -> void:
	if animation_name == "" or animation_name == current_animation:
		return

	var animation_state := spine_sprite.get_animation_state()
	if animation_state == null:
		return

	var track_entry := animation_state.set_animation(animation_name, loop, 0)
	if track_entry == null and animation_name == idle_animation and run_animation != "":
		animation_state.set_animation(run_animation, loop, 0)
		animation_state.set_time_scale(0.0)
		current_animation = idle_animation
		idle_uses_run_fallback = true
		return

	idle_uses_run_fallback = false
	if track_entry != null:
		current_animation = animation_name


func can_move() -> bool:
	return GameManager.curr_state == GameManager.GameStates.PLAYING
