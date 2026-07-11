extends CharacterBody2D
class_name Player

@export var fallback_speed: float = 200.0
@export var run_speed_threshold: float = 20.0
@export var run_animation: String = "run_forward"
@export var idle_animation: String = "idle"
## Offset del laser respecto al centro del player (manos flotantes).
@export var laser_mount_offset: Vector2 = Vector2(0, -80)

@onready var movement_component: MovementComponent = $MovementComponent
@onready var spine_sprite: SpineSprite = $SpineSprite
@onready var laser_mount: Node2D = $LaserMount
@onready var laser_weapon: LaserWeapon = $LaserMount/LaserWeapon

var input_direction: Vector2 = Vector2.ZERO
var facing_direction: Vector2 = Vector2.RIGHT
var aim_direction: Vector2 = Vector2.RIGHT
var current_animation: String = ""
var idle_uses_run_fallback: bool = false
var mine_timer: float = 0.0


func _ready() -> void:
	y_sort_enabled = true
	laser_mount.position = laser_mount_offset
	sync_laser_stats()
	play_animation(idle_animation, true)


func _physics_process(delta: float) -> void:
	mine_timer = maxf(mine_timer - delta, 0.0)

	if can_move():
		get_input_direction()
		move_player(delta)
		update_facing()
		update_laser(delta)
	else:
		move_player(delta, true)
		laser_weapon.is_casting = false

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


## Rota el laser 360° hacia el mouse y dispara mientras se sostiene use_laser.
func update_laser(_delta: float) -> void:
	aim_at_mouse()

	var wants_laser := Input.is_action_pressed("use_laser")
	if wants_laser and not laser_weapon.is_casting:
		sync_laser_stats()

	laser_weapon.is_casting = wants_laser

	if wants_laser:
		try_mine()


func aim_at_mouse() -> void:
	var mouse_pos := get_global_mouse_position()
	var to_mouse := mouse_pos - laser_mount.global_position

	if to_mouse.length_squared() < 0.01:
		return

	aim_direction = to_mouse.normalized()
	laser_mount.look_at(mouse_pos)

	## Mantiene el sprite del arma derecho al apuntar a la izquierda (como la referencia).
	laser_mount.scale.y = -1.0 if aim_direction.x < 0.0 else 1.0


func try_mine() -> void:
	if mine_timer > 0.0:
		return

	var ore := laser_weapon.get_hit_ore()
	if ore == null:
		return

	ore.take_damage(get_attack_damage())
	mine_timer = get_attack_cooldown()


func sync_laser_stats() -> void:
	if laser_weapon == null:
		return
	laser_weapon.set_max_length(get_laser_length())


func get_move_speed() -> float:
	if GameManager.player_stats != null:
		return GameManager.player_stats.speed
	return fallback_speed


func get_attack_damage() -> float:
	if GameManager.player_stats != null:
		return GameManager.player_stats.get_stat("attack")
	return 10.0


func get_attack_cooldown() -> float:
	if GameManager.player_stats != null:
		return GameManager.player_stats.get_stat("attack_cooldown")
	return 0.5


func get_laser_length() -> float:
	if GameManager.player_stats != null:
		return GameManager.player_stats.get_stat("laser_length")
	return 400.0


func apply_facing_flip() -> void:
	if absf(facing_direction.x) < 0.01:
		return

	var base_scale := absf(spine_sprite.scale.x)
	spine_sprite.scale.x = base_scale if facing_direction.x >= 0.0 else -base_scale


func update_animation() -> void:
	var is_moving := velocity.length() > run_speed_threshold
	var animation_name := run_animation if is_moving else idle_animation
	play_animation(animation_name, true)
	sync_animation_speed(is_moving)


func sync_animation_speed(is_moving: bool) -> void:
	var animation_state := spine_sprite.get_animation_state()
	if animation_state == null:
		return

	if not is_moving:
		animation_state.set_time_scale(0.0 if idle_uses_run_fallback else 1.0)
		return

	var base_speed := fallback_speed
	if GameManager.player_stats_base != null:
		base_speed = maxf(GameManager.player_stats_base.speed, 1.0)

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
