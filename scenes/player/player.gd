extends MinerBody
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

@export_group("Lightning Test")
@export var lightning_hops: int = 8
@export var lightning_range_cells: int = 3

@onready var spine_sprite: SpineSprite = $SpineSprite
@onready var weapon_mount: Node2D = $Weapon
@onready var dust_vfx: GPUParticles2D = $DustVFX

var input_direction: Vector2 = Vector2.ZERO
var current_animation: String = ""
var idle_uses_run_fallback: bool = false
var equipped_weapon: WeaponData
var is_chaining: bool = false


func _ready() -> void:
	y_sort_enabled = true
	weapon_mount.position = weapon_mount_offset
	apply_equipped_weapon()
	if not drill_weapon.ore_hit.is_connected(_on_drill_ore_hit):
		drill_weapon.ore_hit.connect(_on_drill_ore_hit)
	play_animation(idle_animation, true)
	dust_vfx.emitting = false


func _physics_process(delta: float) -> void:
	if can_move():
		get_input_direction()
		move_intent = input_direction
	else:
		input_direction = Vector2.ZERO
		move_intent = Vector2.ZERO
	tick_miner(delta, get_move_speed(), get_attack_damage())
	apply_facing_flip()
	update_dust_vfx()
	update_animation()


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_accept"):
		play_test_lightning()


## Prueba del skill: un hop a la vez, siempre el bloque vivo mas cercano a X celdas.
func play_test_lightning() -> void:
	if is_chaining or not can_move():
		return

	is_chaining = true
	var chainer: Chainer = ChainLightning.new()
	Refs.mine_zone.add_child(chainer)

	var spawner := Refs.mine_zone.ore_spawner
	var exclude := {}
	var from_cell := spawner.grid.world_to_cell(global_position)
	var prev_pos := global_position
	var damage := get_attack_damage()

	for i in lightning_hops:
		var ore := spawner.get_chain_ore(from_cell, lightning_range_cells, exclude)
		if ore == null:
			break
		var hop_cell := ore.grid_cell
		exclude[hop_cell] = true
		await chainer.chain(prev_pos, ore)
		if not spawner.owns_live_block(hop_cell, ore):
			from_cell = hop_cell
			continue
		ore.take_damage(damage)
		prev_pos = ore.global_position
		from_cell = hop_cell
		await get_tree().create_timer(chainer.time_between_chains()).timeout

	chainer.queue_free()
	is_chaining = false



func get_input_direction() -> void:
	input_direction = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if input_direction.length_squared() > 1.0:
		input_direction = input_direction.normalized()


## Polvo detras del player mientras hay velocity.
func update_dust_vfx() -> void:
	var moving := velocity.length() > dust_move_threshold
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


func apply_equipped_weapon() -> void:
	equipped_weapon = WeaponData.load_by_id(GameManager.equipped_weapon_id)
	if equipped_weapon == null:
		equipped_weapon = WeaponData.load_by_id("drill_basic")
	sync_weapon_stats()


func sync_weapon_stats() -> void:
	if equipped_weapon == null:
		return
	drill_weapon.setup(equipped_weapon)


func get_move_speed() -> float:
	return Stats.get_stat(Stats.PLAYER_SPEED)


func get_attack_damage() -> float:
	return Stats.get_stat(Stats.PLAYER_DMG)


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

	var base_speed := maxf(Stats.get_base(Stats.PLAYER_SPEED), 1.0)

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
