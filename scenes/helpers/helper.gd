extends MinerBody
class_name Helper
## Minero autonomo de una run. Mismo body+drill que el player; el brain solo vaga.

@onready var visuals: Node2D = $Visuals
@onready var body: Sprite2D = %Body
@onready var face: Sprite2D = %Face
@onready var brain: HelperBrain = $Brain

var data: HelperData
var spawner: OreSpawner
var logical_hit_timer: float = 0.0
var is_active: bool = false


func _ready() -> void:
	y_sort_enabled = true
	brain.setup(self)
	if not drill_weapon.ore_hit.is_connected(_on_drill_ore_hit):
		drill_weapon.ore_hit.connect(_on_drill_ore_hit)


func _physics_process(delta: float) -> void:
	if not is_active or GameManager.curr_state != GameManager.GameStates.PLAYING:
		return
	brain.tick(delta)
	reveal_walked_cells()
	chip_logical_contact(delta)
	tick_miner(delta, get_move_speed(), get_attack_damage())
	look_toward(aim_direction)


func setup(ore_spawner: OreSpawner, helper_data: HelperData, start_cell: Vector2i) -> void:
	spawner = ore_spawner
	data = helper_data
	global_position = spawner.get_cell_world_position(start_cell)
	drill_weapon.hit_delay = get_hit_delay()
	drill_weapon.requires_durability = false
	apply_look()
	is_active = true
	brain.pick_heading()
	reveal_walked_cells()


func shutdown() -> void:
	is_active = false


func look_toward(direction: Vector2) -> void:
	if direction.length_squared() < 0.001:
		return
	visuals.rotation = direction.angle()


func apply_look() -> void:
	if data == null:
		return
	body.modulate = data.tint
	if data.icon != null:
		face.texture = data.icon


## Genera kinds en body y tip para que el tunel exista al volver el player.
func reveal_walked_cells() -> void:
	spawner.ensure_generated(current_cell())
	spawner.ensure_generated(tip_cell())


## Culled: no hay Area2D. Oneshot al paso; si el HP aguanta, chip con el mismo delay del drill.
func chip_logical_contact(delta: float) -> void:
	logical_hit_timer = maxf(logical_hit_timer - delta, 0.0)
	if not has_logical_contact():
		return
	var cell := get_logical_contact_cell()
	var damage := get_attack_damage()
	if spawner.get_cell_hp(cell) <= damage:
		spawner.mine_cell(cell, damage)
		return
	if logical_hit_timer > 0.0:
		return
	logical_hit_timer = drill_weapon.get_hit_delay()
	spawner.mine_cell(cell, damage)


func get_move_speed() -> float:
	return Stats.get_stat(Stats.HELPER_SPEED)


func get_attack_damage() -> float:
	return Stats.get_stat(Stats.HELPER_DMG)


func get_hit_delay() -> float:
	return data.hit_delay if data != null else 0.35


func current_cell() -> Vector2i:
	return spawner.grid.world_to_cell(global_position)


func tip_cell() -> Vector2i:
	return spawner.grid.world_to_cell(drill_weapon.get_drill_tip_global())


## Celda solida sin visual: el tip, o el body si estamos dentro de un bloque culled.
func get_logical_contact_cell() -> Vector2i:
	var tip := tip_cell()
	if is_logical_solid(tip):
		return tip
	return current_cell()


## Frena tambien si el bloque culled delante no muere de un golpe.
func should_stop_for_drill() -> bool:
	if super.should_stop_for_drill():
		return true
	if not has_logical_contact():
		return false
	return spawner.get_cell_hp(get_logical_contact_cell()) > get_attack_damage()


func has_logical_contact() -> bool:
	return is_logical_solid(tip_cell()) or is_logical_solid(current_cell())


func is_logical_solid(cell: Vector2i) -> bool:
	return spawner.is_solid(cell) and not spawner.has_live_block(cell)


func is_busy() -> bool:
	return is_active


func get_marker_world_pos() -> Vector2:
	return global_position


func get_marker_icon() -> Texture2D:
	return data.icon if data != null else null


func is_marker_active() -> bool:
	return is_active and is_inside_tree()


func _on_drill_ore_hit(ore: Ore, damage: float) -> void:
	Feedbacks.spawn_damage_text(damage, ore.damage_marker.global_position, aim_direction)
