extends Node2D
class_name DrillWeapon
## Pega al ore en contacto. El player no se frena a mano: el StaticBody del ore lo para.

signal drilling_started(ore: Ore)
signal drilling_stopped
signal ore_hit(ore: Ore, damage: float)

@export var pivot_path: NodePath = ^"Pivot"
@export var sprite_path: NodePath = ^"Pivot/Sprite"
@export var contact_path: NodePath = ^"ContactArea"
@onready var drill_vfx: GPUParticles2D = %DrillVFX
## Segundos entre golpes mientras hay contacto.
@export var hit_delay: float = 0.3
## Offset local del tip del drill (along +X del pivot).
@export var tip_local_offset: Vector2 = Vector2(80.0, 0.0)

var weapon_data: WeaponData
var pivot: Node2D
var bit_sprite: Sprite2D
var contact_area: Area2D

var overlapping_ores: Array[Ore] = []
var mining_ore: Ore
var hit_timer: float = 0.0
var aim_direction: Vector2 = Vector2.RIGHT
var was_drilling: bool = false


func _ready() -> void:
	pivot = get_node(pivot_path) as Node2D
	bit_sprite = get_node(sprite_path) as Sprite2D
	contact_area = get_node(contact_path) as Area2D
	drill_vfx.emitting = false


func _physics_process(delta: float) -> void:
	update_drill_rotation(delta)


func setup(data: WeaponData) -> void:
	weapon_data = data
	if data != null:
		hit_delay = data.drill_hit_delay


func set_aim_direction(direction: Vector2) -> void:
	if direction.length_squared() > 0.0001:
		aim_direction = direction.normalized()


func is_drilling() -> bool:
	return mining_ore != null and is_instance_valid(mining_ore) and mining_ore.is_alive()


func get_hit_delay() -> float:
	return maxf(hit_delay, 0.05)


func get_damage(base_attack: float) -> float:
	return base_attack


## Contacto = tip Area2D ∪ body slide. Si hay input, pega al ore mas cercano.
func tick(base_attack: float, delta: float, has_move_intent: bool, body_push_ores: Array[Ore]) -> void:
	hit_timer = maxf(hit_timer - delta, 0.0)
	sync_contacts(body_push_ores)

	if GameManager.get_drill_durability() <= 0.0 or not has_move_intent:
		mining_ore = null
		update_drilling_state()
		return

	mining_ore = find_closest_ore()
	update_drilling_state()
	if mining_ore == null:
		return
	if hit_timer > 0.0:
		return

	hit_timer = get_hit_delay()
	deal_hit(mining_ore, get_damage(base_attack))


func sync_contacts(body_push_ores: Array[Ore]) -> void:
	overlapping_ores.clear()
	for body in contact_area.get_overlapping_bodies():
		track_ore(body)
	for ore in body_push_ores:
		if ore == null or not is_instance_valid(ore) or not ore.is_alive():
			continue
		if overlapping_ores.has(ore):
			continue
		overlapping_ores.append(ore)


func find_closest_ore() -> Ore:
	var best: Ore = null
	var best_dist_sq := INF
	var tip := get_drill_tip_global()
	for ore in overlapping_ores:
		if ore == null or not ore.is_alive():
			continue
		var dist_sq := tip.distance_squared_to(ore.global_position)
		if dist_sq < best_dist_sq:
			best_dist_sq = dist_sq
			best = ore
	return best


func deal_hit(ore: Ore, damage: float) -> void:
	if ore == null or not ore.is_alive():
		return
	ore.take_damage(damage)
	ore_hit.emit(ore, damage)
	if not ore.is_alive():
		mining_ore = null


func update_drill_rotation(delta: float) -> void:
	var target_angle := aim_direction.angle()
	var smooth := weapon_data.rotation_smoothing if weapon_data != null else 16.0
	pivot.rotation = lerp_angle(pivot.rotation, target_angle, clampf(smooth * delta, 0.0, 1.0))
	pivot.scale = Vector2.ONE


func update_drilling_state() -> void:
	var drilling_now := is_drilling()
	drill_vfx.emitting = drilling_now
	if drilling_now and not was_drilling:
		drilling_started.emit(mining_ore)
	elif not drilling_now and was_drilling:
		drilling_stopped.emit()
	was_drilling = drilling_now


func get_drill_tip_global() -> Vector2:
	return pivot.to_global(tip_local_offset)


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
	if ore == null or not ore.is_alive() or overlapping_ores.has(ore):
		return
	overlapping_ores.append(ore)


func _on_contact_body_entered(body: Node) -> void:
	track_ore(body)


func _on_contact_body_exited(body: Node) -> void:
	var ore := resolve_ore(body)
	if ore != null:
		overlapping_ores.erase(ore)
