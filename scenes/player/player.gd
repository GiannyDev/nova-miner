extends CharacterBody2D
class_name Player

signal dealt_damage(amount: float)

@export var fallback_speed: float = 200.0
@export var run_speed_threshold: float = 20.0
@export var run_animation: String = "run_forward"
@export var idle_animation: String = "idle"
@export var weapon_mount_offset: Vector2 = Vector2(0, -80)

@export_group("Dust VFX")
@export var dust_move_threshold: float = 1.0
@export var dust_trail_offset: float = 7.0
@export var dust_y_bias: float = 3.0

@onready var movement_component: MovementComponent = $MovementComponent
@onready var spine_sprite: SpineSprite = $SpineSprite
@onready var weapon_mount: Node2D = $Weapon
@onready var drill_weapon: DrillWeapon = %DrillBase
@onready var dust_vfx: GPUParticles2D = $DustVFX

var input_direction: Vector2 = Vector2.ZERO
var facing_direction: Vector2 = Vector2.RIGHT
var aim_direction: Vector2 = Vector2.RIGHT
var current_animation: String = ""
var idle_uses_run_fallback: bool = false
var equipped_weapon: WeaponData


func _ready() -> void:
	y_sort_enabled = true
	weapon_mount.position = weapon_mount_offset
	apply_equipped_weapon()
	connect_drill_damage_tracking()
	play_animation(idle_animation, true)
	if dust_vfx != null:
		dust_vfx.emitting = false


func connect_drill_damage_tracking() -> void:
	if drill_weapon != null and not drill_weapon.ore_hit.is_connected(_on_drill_ore_hit):
		drill_weapon.ore_hit.connect(_on_drill_ore_hit)


func _physics_process(delta: float) -> void:
	if can_move():
		get_input_direction()
		update_facing()
		update_drill_weapon(delta)
		move_player(delta)
	else:
		move_player(delta, true)
	update_dust_vfx()
	update_animation()


func get_input_direction() -> void:
	input_direction = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if input_direction.length_squared() > 1.0:
		input_direction = input_direction.normalized()


func move_player(delta: float, decelerate_only: bool = false) -> void:
	var direction := Vector2.ZERO if decelerate_only else input_direction

	if is_drill_engaged():
		movement_component.hard_stop(self)
		return

	movement_component.move(self, direction, delta, get_move_speed())


## Polvo detras del player mientras hay velocity; se apaga al perforar / idle.
func update_dust_vfx() -> void:
	if dust_vfx == null:
		return

	var moving := velocity.length() > dust_move_threshold and not is_drill_engaged()
	dust_vfx.emitting = moving
	if not moving:
		return

	var move_dir := velocity.normalized()
	var trail_dir := -move_dir
	# Material apunta a -X local: rotar con move_dir hace que el polvo salga detras.
	dust_vfx.rotation = move_dir.angle()
	dust_vfx.position = Vector2(dust_trail_offset, 0.0).rotated(trail_dir.angle())
	dust_vfx.position.y += trail_dir.y * dust_y_bias
	dust_vfx.show_behind_parent = trail_dir.y < 0.3


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
	var attack := get_attack_damage()
	var drill_aim := get_drill_aim_direction()
	aim_direction = drill_aim
	drill_weapon.set_aim_direction(drill_aim)
	drill_weapon.update_latching(has_move_intent, attack)
	drill_weapon.tick(attack, delta)


## Solo movimiento / ultimo facing. Nunca apunta al ore (evita flick al destruir).
func get_drill_aim_direction() -> Vector2:
	if input_direction.length_squared() > 0.01:
		return input_direction.normalized()

	if facing_direction.length_squared() > 0.01:
		return facing_direction.normalized()

	return Vector2.RIGHT


func apply_equipped_weapon() -> void:
	equipped_weapon = WeaponData.load_by_id(GameManager.equipped_weapon_id)
	if equipped_weapon == null:
		equipped_weapon = WeaponData.load_by_id("drill_basic")

	sync_weapon_stats()


func sync_weapon_stats() -> void:
	if equipped_weapon == null:
		return

	elif drill_weapon != null:
		drill_weapon.setup(equipped_weapon)


func is_drill_locked() -> bool:
	return is_drill_engaged()


## Hold estable: perforando, grace tras soltar, o empujando contra contacto.
func is_drill_engaged() -> bool:
	return drill_weapon != null and drill_weapon.should_hold_player()


func get_move_speed() -> float:
	if GameManager.player_stats != null:
		return GameManager.player_stats.get_stat(int(Stats.PLAYER_SPEED))
	return fallback_speed


func get_attack_damage() -> float:
	if GameManager.player_stats != null:
		return GameManager.player_stats.get_stat(int(Stats.PLAYER_DMG))
	return 10.0


func get_attack_cooldown() -> float:
	if GameManager.player_stats != null:
		return GameManager.player_stats.get_stat(int(Stats.PLAYER_ATTACK_COOLDOWN))
	return 0.5


func apply_facing_flip() -> void:
	if absf(facing_direction.x) < 0.01:
		return

	var base_scale := absf(spine_sprite.scale.x)
	spine_sprite.scale.x = base_scale if facing_direction.x >= 0.0 else -base_scale


func update_animation() -> void:
	#if is_drill_engaged():
		## Pose de empuje: run congelado. No swap a idle (ese cambio causaba flicker).
		#play_animation(run_animation, true)
		#set_animation_time_scale(0.0)
		#return

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


func _on_drill_ore_hit(ore: Ore, damage: float) -> void:
	dealt_damage.emit(damage)
	# Sale del marker del ore y flota en direccion opuesta a donde miramos.
	Feedbacks.spawn_damage_text(damage, ore.damage_marker.global_position, aim_direction)
