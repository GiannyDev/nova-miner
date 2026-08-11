extends Node2D
class_name DrillWeapon

signal drilling_started(ore: Ore)
signal drilling_stopped
signal ore_hit(ore: Ore, damage: float)

@export var pivot_path: NodePath = ^"Pivot"
@export var sprite_path: NodePath = ^"Pivot/Sprite"
@export var contact_path: NodePath = ^"ContactArea"
@onready var drill_vfx: GPUParticles2D = %DrillVFX
## Segundos entre golpes mientras hay contacto. Editable en Inspector.
@export var hit_delay: float = 0.3
## Distancia tip→ore para soltar el latch si ya no hay overlap.
@export var latch_break_distance: float = 160.0
## Freno breve tras romper un multi-hit (evita teleporte al hueco). Oneshots no lo usan.
@export var hold_grace: float = 0.08
## Duracion del burst de particulas al romper oneshot sin latch.
@export var oneshot_vfx_duration: float = 0.15
## Offset local del tip del drill (along +X del pivot).
@export var tip_local_offset: Vector2 = Vector2(80.0, 0.0)

var weapon_data: WeaponData
var pivot: Node2D
var bit_sprite: Sprite2D
var contact_area: Area2D

var overlapping_ores: Array[Ore] = []
var body_push_ores: Array[Ore] = []
var latched_ore: Ore
## Cooldown global de ataque. Nunca se resetea al (re)latchear.
var hit_timer: float = 0.0
var aim_direction: Vector2 = Vector2.RIGHT
var was_drilling: bool = false
var hold_timer: float = 0.0
var oneshot_vfx_timer: float = 0.0


func _ready() -> void:
	pivot = get_node_or_null(pivot_path) as Node2D
	bit_sprite = get_node_or_null(sprite_path) as Sprite2D
	contact_area = get_node_or_null(contact_path) as Area2D
	set_drill_vfx_emitting(false)


func _physics_process(delta: float) -> void:
	sync_contacts()
	tick_hold_timer(delta)
	tick_oneshot_vfx(delta)
	update_drill_rotation(delta)
	update_drilling_state()


func setup(data: WeaponData) -> void:
	weapon_data = data
	if data != null:
		hit_delay = data.drill_hit_delay


func set_aim_direction(direction: Vector2) -> void:
	if direction.length_squared() > 0.0001:
		aim_direction = direction.normalized()


func set_body_push_ores(ores: Array[Ore]) -> void:
	body_push_ores = ores


func is_drilling() -> bool:
	return latched_ore != null and is_instance_valid(latched_ore) and latched_ore.is_alive()


func get_latched_ore() -> Ore:
	return latched_ore if is_drilling() else null


func get_hit_delay() -> float:
	return maxf(hit_delay, 0.05)


func get_damage(base_attack: float) -> float:
	return base_attack


func should_hold_player() -> bool:
	return is_drilling() or hold_timer > 0.0


func refresh_hold() -> void:
	hold_timer = maxf(hold_timer, hold_grace)


func clear_hold() -> void:
	hold_timer = 0.0


func tick_hold_timer(delta: float) -> void:
	if is_drilling():
		hold_timer = hold_grace
		return
	if hold_timer > 0.0:
		hold_timer = maxf(hold_timer - delta, 0.0)


func can_oneshot(ore: Ore, base_attack: float) -> bool:
	if ore == null or not is_instance_valid(ore) or not ore.is_alive():
		return false
	return get_damage(base_attack) >= ore.current_hp


## Contacto = tip Area2D ∪ body slide.
func sync_contacts() -> void:
	overlapping_ores.clear()
	if contact_area != null:
		for body in contact_area.get_overlapping_bodies():
			track_ore(body)
	for ore in body_push_ores:
		if ore == null or not is_instance_valid(ore) or ore.is_destroyed or not ore.is_alive():
			continue
		if overlapping_ores.has(ore):
			continue
		overlapping_ores.append(ore)
	clean_overlapping_ores()


## Solo engancha multi-hit. Oneshots nunca frenan al player.
func update_latching(has_move_intent: bool, base_attack: float) -> void:
	if GameManager.get_drill_durability() <= 0.0:
		release_latch()
		clear_hold()
		return

	sync_contacts()

	if not has_move_intent:
		release_latch()
		clear_hold()
		return

	if is_drilling():
		if not is_ore_in_drill_reach(latched_ore) or can_oneshot(latched_ore, base_attack):
			# Si ahora one-shottea, suelta el hold: tick lo rompera sin frenar.
			release_latch()
			clear_hold()
		else:
			refresh_hold()
			return

	var next := find_best_multihit_ore(base_attack)
	if next != null:
		latch_ore(next)
		refresh_hold()


## Oneshots al contacto (sin cooldown/hold). Multi-hit respeta hit_delay.
func tick(base_attack: float, delta: float, has_move_intent: bool = true) -> void:
	hit_timer = maxf(hit_timer - delta, 0.0)

	if GameManager.get_drill_durability() <= 0.0:
		return
	if not has_move_intent:
		return

	sync_contacts()

	# Oneshots: rompe al tocar. Sin hold, con VFX — movimiento caotico fluido.
	smash_oneshot_contacts(base_attack)

	if hit_timer > 0.0:
		return
	if not is_drilling():
		return
	if not is_ore_in_drill_reach(latched_ore):
		release_latch()
		return

	hit_timer = get_hit_delay()
	deal_multihit(latched_ore, base_attack)


## Rompe todos los oneshots en contacto. True si rompio al menos uno.
func smash_oneshot_contacts(base_attack: float) -> bool:
	var smashed := false
	var contacts := overlapping_ores.duplicate()
	for ore in contacts:
		if not can_oneshot(ore, base_attack):
			continue
		deal_oneshot(ore, get_damage(base_attack))
		smashed = true
	return smashed


## Oneshot: un ore_hit + VFX + destroy. Nunca refresh_hold (movimiento caotico).
func deal_oneshot(ore: Ore, damage: float) -> void:
	if ore == null or not is_instance_valid(ore) or not ore.is_alive():
		return
	ore_hit.emit(ore, damage)
	pulse_drill_vfx()
	ore.destroy_instant()
	if latched_ore == ore:
		release_latch()
	clear_hold()


## Multi-hit latcheado: chips con squash, o golpe final letal.
func deal_multihit(ore: Ore, base_attack: float) -> void:
	if ore == null or not is_instance_valid(ore) or not ore.is_alive():
		release_latch()
		return

	var damage := get_damage(base_attack)

	if can_oneshot(ore, base_attack):
		# Ultimo golpe de un grind: VFX + destroy. Grace breve anti-teleporte.
		ore_hit.emit(ore, damage)
		pulse_drill_vfx()
		ore.destroy_instant()
		release_latch()
		refresh_hold()
		return

	ore.take_damage(damage)
	ore_hit.emit(ore, damage)

	if not is_instance_valid(ore) or ore.is_destroyed or not ore.is_alive():
		release_latch()
		refresh_hold()


func clean_overlapping_ores() -> void:
	for i in range(overlapping_ores.size() - 1, -1, -1):
		var ore := overlapping_ores[i]
		if ore == null or not is_instance_valid(ore) or ore.is_destroyed:
			overlapping_ores.remove_at(i)


func update_drill_rotation(delta: float) -> void:
	if pivot == null:
		return

	var target_angle := aim_direction.angle()
	var smooth := weapon_data.rotation_smoothing if weapon_data != null else 16.0
	pivot.rotation = lerp_angle(pivot.rotation, target_angle, clampf(smooth * delta, 0.0, 1.0))
	pivot.scale = Vector2.ONE


func update_drill_spin(delta: float) -> void:
	if bit_sprite == null:
		return

	var spin := weapon_data.drill_spin_speed if weapon_data != null else 14.0
	bit_sprite.rotation += spin * delta


func update_drilling_state() -> void:
	var drilling_now := is_drilling()
	if drilling_now and not was_drilling:
		drilling_started.emit(latched_ore)
		set_drill_vfx_emitting(true)
	elif not drilling_now and was_drilling:
		drilling_stopped.emit()
		# No apagues si hay burst oneshot activo.
		if oneshot_vfx_timer <= 0.0:
			set_drill_vfx_emitting(false)
	was_drilling = drilling_now


func set_drill_vfx_emitting(active: bool) -> void:
	if drill_vfx == null:
		return
	drill_vfx.emitting = active


## Burst corto al picar oneshot (sin latch continuo).
func pulse_drill_vfx() -> void:
	if drill_vfx == null:
		return
	drill_vfx.emitting = true
	drill_vfx.restart()
	oneshot_vfx_timer = maxf(oneshot_vfx_timer, oneshot_vfx_duration)


func tick_oneshot_vfx(delta: float) -> void:
	if oneshot_vfx_timer <= 0.0:
		return
	oneshot_vfx_timer = maxf(oneshot_vfx_timer - delta, 0.0)
	if oneshot_vfx_timer <= 0.0 and not is_drilling():
		set_drill_vfx_emitting(false)


## Cambia el target. NO toca hit_timer (el cooldown es global).
func latch_ore(ore: Ore) -> void:
	if ore == null or ore.is_destroyed:
		return
	if latched_ore == ore:
		return
	latched_ore = ore


func release_latch() -> void:
	latched_ore = null


func is_ore_in_drill_reach(ore: Ore) -> bool:
	if ore == null or not is_instance_valid(ore):
		return false
	if overlapping_ores.has(ore):
		return true
	var tip := get_drill_tip_global()
	var break_dist := maxf(latch_break_distance, 1.0)
	return tip.distance_squared_to(ore.global_position) <= break_dist * break_dist


func get_drill_tip_global() -> Vector2:
	if pivot != null:
		return pivot.to_global(tip_local_offset)
	return global_position + aim_direction * tip_local_offset.x


## Solo ores multi-hit (ATK < HP). Oneshots no se latchan.
func find_best_multihit_ore(base_attack: float) -> Ore:
	var best: Ore = null
	var best_dist_sq := INF
	var tip := get_drill_tip_global()

	for ore in overlapping_ores:
		if ore == null or ore.is_destroyed or not ore.is_alive():
			continue
		if can_oneshot(ore, base_attack):
			continue
		var dist_sq := tip.distance_squared_to(ore.global_position)
		if dist_sq < best_dist_sq:
			best_dist_sq = dist_sq
			best = ore

	return best


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
