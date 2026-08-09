extends Node2D
class_name DrillWeapon

signal drilling_started(ore: Ore)
signal drilling_stopped
signal ore_hit(ore: Ore, damage: float)

@export var pivot_path: NodePath = ^"Pivot"
@export var sprite_path: NodePath = ^"Pivot/Sprite"
@export var contact_path: NodePath = ^"ContactArea"
@onready var drill_vfx: GPUParticles2D = %DrillVFX
## Distancia tip→ore para soltar el latch si el Area2D ya no reporta overlap.
@export var latch_break_distance: float = 160.0
## Freno breve solo si no hay siguiente ore en contacto (cadena continua no lo usa).
@export var hold_grace: float = 0.08
## Offset local del tip del drill (along +X del pivot).
@export var tip_local_offset: Vector2 = Vector2(80.0, 0.0)

var weapon_data: WeaponData
var pivot: Node2D
var bit_sprite: Sprite2D
var contact_area: Area2D

var overlapping_ores: Array[Ore] = []
var latched_ore: Ore
var hit_timer: float = 0.0
var aim_direction: Vector2 = Vector2.RIGHT
var was_drilling: bool = false
var hold_timer: float = 0.0


func _ready() -> void:
	pivot = get_node_or_null(pivot_path) as Node2D
	bit_sprite = get_node_or_null(sprite_path) as Sprite2D
	contact_area = get_node_or_null(contact_path) as Area2D
	set_drill_vfx_emitting(false)


func _physics_process(delta: float) -> void:
	# Resync: si el drill ya esta dentro de un ore (p.ej. stack vertical tras romper el de abajo),
	# body_entered no vuelve a disparar — hay que leer overlaps actuales del Area2D.
	sync_overlapping_from_area()
	tick_hold_timer(delta)
	update_drill_rotation(delta)
	update_drilling_state()


## Avanza el timer de golpes y aplica dano cuando toca (llamado desde Player con attack actual).
func tick(base_attack: float, delta: float) -> void:
	if GameManager.get_drill_durability() <= 0.0:
		return
	if not is_drilling():
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
	return base_attack


## True solo si hay latch multi-hit activo o grace tras soltar un multi-hit.
## One-shots no frenan al player (sigue corriendo mientras destroza).
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


func has_contact_ores() -> bool:
	return not overlapping_ores.is_empty()


func can_oneshot(ore: Ore, base_attack: float) -> bool:
	if ore == null or not is_instance_valid(ore) or not ore.is_alive():
		return false
	return get_damage(base_attack) >= ore.current_hp


## Latch sticky multi-hit. One-shots se rompen al paso sin detener al player.
func update_latching(has_move_intent: bool, base_attack: float) -> void:
	if GameManager.get_drill_durability() <= 0.0:
		release_latch()
		clear_hold()
		return

	sync_overlapping_from_area()

	if latched_ore != null:
		if not is_instance_valid(latched_ore) or latched_ore.is_destroyed or not latched_ore.is_alive():
			release_latch()
			try_chain_latch(has_move_intent, base_attack)
			return
		if not has_move_intent:
			release_latch()
			clear_hold()
			return
		if not is_ore_in_drill_reach(latched_ore):
			release_latch()
			try_chain_latch(has_move_intent, base_attack)
			return
		# Si el ATK subio y ahora one-shotea el latched, rompelo y sigue.
		if can_oneshot(latched_ore, base_attack):
			smash_ore(latched_ore, base_attack)
			release_latch()
			try_chain_latch(has_move_intent, base_attack)
			return
		refresh_hold()
		return

	if not has_move_intent:
		clear_hold()
		return

	try_chain_latch(true, base_attack)


func try_chain_latch(has_move_intent: bool, base_attack: float) -> void:
	if not has_move_intent:
		return

	sync_overlapping_from_area()
	# Primero destroza todo lo one-shotteable en contacto (sin hold).
	smash_oneshot_contacts(base_attack)
	sync_overlapping_from_area()

	var ore := find_best_multihit_ore(base_attack)
	if ore != null:
		latch_ore(ore, true)
		refresh_hold()
	else:
		# Solo one-shots o nada: no frenes, sigue corriendo.
		clear_hold()


## Rompe en el acto todos los ores de contacto que mueren de un golpe.
func smash_oneshot_contacts(base_attack: float) -> void:
	var contacts := overlapping_ores.duplicate()
	for ore in contacts:
		if not can_oneshot(ore, base_attack):
			continue
		if not is_ore_in_front(ore):
			continue
		smash_ore(ore, base_attack)
	clean_overlapping_ores()


func smash_ore(ore: Ore, base_attack: float) -> void:
	if ore == null or not is_instance_valid(ore) or not ore.is_alive():
		return
	var damage := get_damage(base_attack)
	ore.take_damage(damage)
	ore_hit.emit(ore, damage)


func is_ore_in_front(ore: Ore) -> bool:
	var to_ore := ore.global_position - global_position
	if to_ore.length_squared() < 0.01:
		return true
	return aim_direction.dot(to_ore.normalized()) >= -0.15


func apply_damage_tick(base_attack: float) -> void:
	if not is_drilling():
		return

	var target := latched_ore
	var damage := get_damage(base_attack)
	target.take_damage(damage)
	ore_hit.emit(target, damage)

	if not is_instance_valid(target) or target.is_destroyed or not target.is_alive():
		release_latch()
		sync_overlapping_from_area()
		# Tras romper multi-hit: encadena. One-shots no activan hold.
		smash_oneshot_contacts(base_attack)
		sync_overlapping_from_area()
		var next := find_best_multihit_ore(base_attack)
		if next != null:
			latch_ore(next, true)
			refresh_hold()
		else:
			clear_hold()


func clean_overlapping_ores() -> void:
	for i in range(overlapping_ores.size() - 1, -1, -1):
		var ore := overlapping_ores[i]
		if ore == null or not is_instance_valid(ore) or ore.is_destroyed:
			overlapping_ores.remove_at(i)


## Fuente de verdad de contacto: lee bodies actuales del Area2D (no solo signals enter/exit).
func sync_overlapping_from_area() -> void:
	overlapping_ores.clear()
	if contact_area == null:
		return
	for body in contact_area.get_overlapping_bodies():
		track_ore(body)
	clean_overlapping_ores()


## ContactArea sigue el aim sin heredar scale del pivot.
func sync_contact_to_aim() -> void:
	if contact_area == null:
		return
	contact_area.rotation = aim_direction.angle()
	contact_area.position = Vector2.ZERO
	contact_area.scale = Vector2.ONE


func update_drill_rotation(delta: float) -> void:
	if pivot == null:
		return

	var target_angle := aim_direction.angle()
	var smooth := weapon_data.rotation_smoothing if weapon_data != null else 16.0
	pivot.rotation = lerp_angle(pivot.rotation, target_angle, clampf(smooth * delta, 0.0, 1.0))
	pivot.scale = Vector2.ONE


## Spin siempre activo: el drill no "asienta" al romper un bloque.
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
		set_drill_vfx_emitting(false)
	was_drilling = drilling_now


## Particles bajo Pivot: velocity local -X = opuesto al aim (+X del drill).
func set_drill_vfx_emitting(active: bool) -> void:
	if drill_vfx == null:
		return
	drill_vfx.emitting = active


## preserve_hit_timer: al encadenar ores mantiene el ritmo de golpe (cadena fluida).
func latch_ore(ore: Ore, preserve_hit_timer: bool = false) -> void:
	if ore == null or ore.is_destroyed:
		return
	if latched_ore == ore:
		return

	latched_ore = ore
	if not preserve_hit_timer:
		hit_timer = 0.0


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


func find_best_contact_ore() -> Ore:
	return find_best_ore_from_contacts(false, 0.0)


## Solo ores que requieren varios golpes (ATK < HP actual).
func find_best_multihit_ore(base_attack: float) -> Ore:
	return find_best_ore_from_contacts(true, base_attack)


func find_best_ore_from_contacts(multihit_only: bool, base_attack: float) -> Ore:
	var best: Ore = null
	var best_score := -INF

	for ore in overlapping_ores:
		if ore == null or ore.is_destroyed or not ore.is_alive():
			continue
		if multihit_only and can_oneshot(ore, base_attack):
			continue

		var to_ore := ore.global_position - global_position
		var dist_sq := to_ore.length_squared()
		if dist_sq < 0.01:
			return ore

		var alignment := aim_direction.dot(to_ore.normalized())
		var score := alignment * 2.0 - sqrt(dist_sq) * 0.001
		if score > best_score:
			best_score = score
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
