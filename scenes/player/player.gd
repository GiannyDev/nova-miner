extends CharacterBody2D
class_name Player

signal dealt_damage(amount: float)

@export var fallback_speed: float = 200.0
@export var run_speed_threshold: float = 20.0
@export var run_animation: String = "run_forward"
@export var idle_animation: String = "idle"
@export var laser_mount_offset: Vector2 = Vector2(0, -80)
@export var weapon_mount_offset: Vector2 = Vector2(0, -80)

@onready var movement_component: MovementComponent = $MovementComponent
@onready var spine_sprite: SpineSprite = $SpineSprite
@onready var laser_mount: Node2D = $LaserMount
@onready var laser_weapon: LaserWeapon = $LaserMount/LaserWeapon
@onready var weapon_mount: Node2D = $Weapon
@onready var drill_weapon: DrillWeapon = %DrillBase

var input_direction: Vector2 = Vector2.ZERO
var facing_direction: Vector2 = Vector2.RIGHT
var aim_direction: Vector2 = Vector2.RIGHT
var current_animation: String = ""
var idle_uses_run_fallback: bool = false
var equipped_weapon: WeaponData
var laser_mine_timer: float = 0.0


func _ready() -> void:
	y_sort_enabled = true
	laser_mount.position = laser_mount_offset
	weapon_mount.position = weapon_mount_offset
	apply_equipped_weapon()
	connect_drill_damage_tracking()
	play_animation(idle_animation, true)


func connect_drill_damage_tracking() -> void:
	if drill_weapon != null and not drill_weapon.ore_hit.is_connected(_on_drill_ore_hit):
		drill_weapon.ore_hit.connect(_on_drill_ore_hit)


func _physics_process(delta: float) -> void:
	laser_mine_timer = maxf(laser_mine_timer - delta, 0.0)

	if can_move():
		get_input_direction()
		update_facing()

		match get_active_weapon_kind():
			WeaponData.WeaponKind.DRILL:
				update_drill_weapon(delta)
			WeaponData.WeaponKind.LASER:
				update_laser_weapon(delta)

		move_player(delta)
	else:
		move_player(delta, true)
		if get_active_weapon_kind() == WeaponData.WeaponKind.LASER:
			laser_weapon.is_casting = false

	update_animation()


func get_input_direction() -> void:
	input_direction = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if input_direction.length_squared() > 1.0:
		input_direction = input_direction.normalized()


func move_player(delta: float, decelerate_only: bool = false) -> void:
	var direction := Vector2.ZERO if decelerate_only else input_direction

	if is_drill_locked():
		movement_component.stop(self, delta)
		return

	movement_component.move(self, direction, delta, get_move_speed())


func update_facing() -> void:
	if input_direction.length_squared() > 0.01:
		facing_direction = input_direction.normalized()
	elif velocity.length_squared() > run_speed_threshold * run_speed_threshold:
		facing_direction = velocity.normalized()

	apply_facing_flip()


func update_drill_weapon(delta: float) -> void:
	if drill_weapon == null:
		return

	var has_move_intent := input_direction.length_squared() > 0.01
	drill_weapon.try_latch_from_movement(has_move_intent)
	var drill_aim := get_drill_aim_direction()
	aim_direction = drill_aim
	drill_weapon.set_aim_direction(drill_aim)
	drill_weapon.tick(get_attack_damage(), delta)


## Solo movimiento / ultimo facing. Nunca apunta al ore (evita flick al destruir).
func get_drill_aim_direction() -> Vector2:
	if input_direction.length_squared() > 0.01:
		return input_direction.normalized()

	if facing_direction.length_squared() > 0.01:
		return facing_direction.normalized()

	return Vector2.RIGHT


func update_laser_weapon(_delta: float) -> void:
	aim_at_mouse()

	var wants_laser := Input.is_action_pressed("use_laser")
	if wants_laser and not laser_weapon.is_casting:
		sync_laser_stats()

	laser_weapon.is_casting = wants_laser

	if wants_laser:
		try_laser_mine()


func aim_at_mouse() -> void:
	var mouse_pos := get_global_mouse_position()
	var to_mouse := mouse_pos - laser_mount.global_position

	if to_mouse.length_squared() < 0.01:
		return

	aim_direction = to_mouse.normalized()
	laser_mount.look_at(mouse_pos)
	laser_mount.scale.y = -1.0 if aim_direction.x < 0.0 else 1.0


func try_laser_mine() -> void:
	if laser_mine_timer > 0.0:
		return

	var ore := laser_weapon.get_hit_ore()
	if ore == null:
		return

	ore.take_damage(get_attack_damage())
	dealt_damage.emit(get_attack_damage())
	laser_mine_timer = get_attack_cooldown()


func apply_equipped_weapon() -> void:
	equipped_weapon = WeaponData.load_by_id(GameManager.equipped_weapon_id)
	if equipped_weapon == null:
		equipped_weapon = WeaponData.load_by_id("drill_basic")

	refresh_weapon_visibility()
	sync_weapon_stats()


func refresh_weapon_visibility() -> void:
	var kind := get_active_weapon_kind()
	laser_mount.visible = kind == WeaponData.WeaponKind.LASER
	weapon_mount.visible = kind == WeaponData.WeaponKind.DRILL


func sync_weapon_stats() -> void:
	if equipped_weapon == null:
		return

	if equipped_weapon.kind == WeaponData.WeaponKind.LASER:
		sync_laser_stats()
	elif drill_weapon != null:
		drill_weapon.setup(equipped_weapon)


func sync_laser_stats() -> void:
	if laser_weapon == null or equipped_weapon == null:
		return

	laser_weapon.set_max_length(equipped_weapon.laser_max_length)
	laser_weapon.set_color(equipped_weapon.laser_color)
	laser_weapon.line_width = equipped_weapon.laser_line_width


func get_active_weapon_kind() -> WeaponData.WeaponKind:
	if equipped_weapon != null:
		return equipped_weapon.kind
	return WeaponData.WeaponKind.DRILL


func is_drill_locked() -> bool:
	return get_active_weapon_kind() == WeaponData.WeaponKind.DRILL and drill_weapon != null and drill_weapon.is_drilling()


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
	if equipped_weapon != null and equipped_weapon.kind == WeaponData.WeaponKind.LASER:
		return equipped_weapon.laser_max_length
	if GameManager.player_stats != null:
		return GameManager.player_stats.get_stat("laser_length")
	return 400.0


func apply_facing_flip() -> void:
	if absf(facing_direction.x) < 0.01:
		return

	var base_scale := absf(spine_sprite.scale.x)
	spine_sprite.scale.x = base_scale if facing_direction.x >= 0.0 else -base_scale


func update_animation() -> void:
	if is_drill_locked():
		play_animation(idle_animation, true)
		set_animation_time_scale(0.0)
		return

	var is_moving := velocity.length() > run_speed_threshold
	var animation_name := run_animation if is_moving else idle_animation
	play_animation(animation_name, true)
	sync_animation_speed(is_moving)


func set_animation_time_scale(time_scale: float) -> void:
	var animation_state := spine_sprite.get_animation_state()
	if animation_state != null:
		animation_state.set_time_scale(time_scale)


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


func _on_drill_ore_hit(_ore: Ore, damage: float) -> void:
	dealt_damage.emit(damage)
