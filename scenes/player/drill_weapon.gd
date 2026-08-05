extends Node2D
class_name DrillWeapon
## Perforador del player: detecta ores en contacto, aplica dano por ticks y feedback visual.
## El player controla aim (movimiento) y bloquea movimiento mientras hay un ore enganchado.

signal drilling_started(ore: Ore)
signal drilling_stopped
signal ore_hit(ore: Ore, damage: float)

@export var pivot_path: NodePath = ^"Pivot"
@export var sprite_path: NodePath = ^"Pivot/Sprite"

var weapon_data: WeaponData
var pivot: Node2D
var bit_sprite: Sprite2D

var overlapping_ores: Array[Ore] = []
var latched_ore: Ore
var hit_timer: float = 0.0
var aim_direction: Vector2 = Vector2.RIGHT
var was_drilling: bool = false


func _ready() -> void:
	pivot = get_node_or_null(pivot_path) as Node2D
	bit_sprite = get_node_or_null(sprite_path) as Sprite2D



func _physics_process(delta: float) -> void:
	clean_overlapping_ores()
	update_latched_ore()
	update_drill_rotation(delta)
	update_drill_spin(delta)
	update_drilling_state()


## Avanza el timer de golpes y aplica dano cuando toca (llamado desde Player con attack actual).
func tick(base_attack: float, delta: float) -> void:
	if not is_drilling():
		hit_timer = 0.0
		return

	hit_timer -= delta
	if hit_timer > 0.0:
		return

	apply_damage_tick(base_attack)
	hit_timer = get_hit_delay()


func setup(data: WeaponData) -> void:
	weapon_data = data


## Direccion hacia donde debe apuntar el drill (normalizada). El player la setea cada frame.
func set_aim_direction(direction: Vector2) -> void:
	if direction.length_squared() > 0.0001:
		aim_direction = direction.normalized()


func is_drilling() -> bool:
	return latched_ore != null and is_instance_valid(latched_ore) and latched_ore.is_alive()


func get_latched_ore() -> Ore:
	return latched_ore if is_drilling() else null


func get_hit_delay() -> float:
	if weapon_data != null:
		return maxf(weapon_data.drill_hit_delay, 0.05)
	return 0.2


func get_damage(base_attack: float) -> float:
	var mult := weapon_data.damage_multiplier if weapon_data != null else 1.0
	return maxf(base_attack * mult, 0.0)


func try_latch_from_movement(has_move_intent: bool) -> void:
	if is_drilling() or not has_move_intent:
		return

	var ore := find_best_contact_ore()
	if ore != null:
		latch_ore(ore)


func apply_damage_tick(base_attack: float) -> void:
	if not is_drilling():
		return

	var damage := get_damage(base_attack)
	latched_ore.take_damage(damage)
	ore_hit.emit(latched_ore, damage)
	play_hit_feedback()


func clean_overlapping_ores() -> void:
	for i in range(overlapping_ores.size() - 1, -1, -1):
		var ore := overlapping_ores[i]
		if ore == null or not is_instance_valid(ore) or ore.is_destroyed:
			overlapping_ores.remove_at(i)


func update_latched_ore() -> void:
	if latched_ore == null:
		return

	if not is_instance_valid(latched_ore) or latched_ore.is_destroyed:
		release_latch()
		return

	if not overlapping_ores.has(latched_ore):
		release_latch()


func update_drill_rotation(delta: float) -> void:
	if pivot == null:
		return

	# Solo aim por movimiento. Nada mas escribe rotation del pivot.
	var target_angle := aim_direction.angle()
	var smooth := weapon_data.rotation_smoothing if weapon_data != null else 16.0
	pivot.rotation = lerp_angle(pivot.rotation, target_angle, clampf(smooth * delta, 0.0, 1.0))


func update_drill_spin(delta: float) -> void:
	if bit_sprite == null:
		return

	if is_drilling():
		var spin := weapon_data.drill_spin_speed if weapon_data != null else 14.0
		bit_sprite.rotation += spin * delta
	else:
		bit_sprite.rotation = lerp_angle(bit_sprite.rotation, 0.0, delta * 12.0)


func update_drilling_state() -> void:
	var drilling_now := is_drilling()
	if drilling_now and not was_drilling:
		drilling_started.emit(latched_ore)
	elif not drilling_now and was_drilling:
		drilling_stopped.emit()
	was_drilling = drilling_now


func latch_ore(ore: Ore) -> void:
	if ore == null or ore.is_destroyed:
		return

	latched_ore = ore
	hit_timer = 0.0


func release_latch() -> void:
	latched_ore = null
	hit_timer = 0.0


func find_best_contact_ore() -> Ore:
	var best: Ore = null
	var best_score := -INF

	for ore in overlapping_ores:
		if ore == null or ore.is_destroyed:
			continue

		var to_ore := ore.global_position - global_position
		if to_ore.length_squared() < 0.01:
			return ore

		var alignment := aim_direction.dot(to_ore.normalized())
		var score := alignment - to_ore.length() * 0.0005
		if score > best_score:
			best_score = score
			best = ore

	return best


func play_hit_feedback() -> void:
	# Squash solo en el bit: el pivot queda exclusivo para aim por movimiento.
	if bit_sprite == null:
		return

	var squash := weapon_data.hit_squash_amount if weapon_data != null else 0.1
	if squash <= 0.0:
		return

	Springer.squash(pivot, squash, -squash * 0.6)


func resolve_ore(body: Node) -> Ore:
	if body == null:
		return null
	if body is Ore:
		return body as Ore
	if body is StaticBody2D:
		return body.get_parent() as Ore
	return null


func track_ore(body: Node) -> void:
	var ore := resolve_ore(body)
	if ore == null or overlapping_ores.has(ore):
		return
	overlapping_ores.append(ore)


func untrack_ore(body: Node) -> void:
	var ore := resolve_ore(body)
	if ore == null:
		return
	overlapping_ores.erase(ore)


func _on_contact_body_entered(body: Node) -> void:
	track_ore(body)


func _on_contact_body_exited(body: Node) -> void:
	untrack_ore(body)
