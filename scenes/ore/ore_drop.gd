extends Node2D
class_name OreDrop
## Drop visual: cae con rebotes y vuela en curva al icono del inventario HUD.

@export var cell_spawn_radius: float = 48.0
@export var drop_y_fall_amount: float = 36.0
@export var first_bounce_height: float = 52.0
@export var second_bounce_height: float = 28.0
@export var lateral_bounce_spread: float = 56.0
@export var fall_duration: float = 0.22
@export var bounce_up_duration: float = 0.18
@export var home_duration: float = 0.45
@export var home_arc_height: float = 90.0

@onready var sprite: Sprite2D = $Sprite2D

var ore_data: OreData
var pickup_amount: int = 1


## Spawnea cerca del bloque, cae con 2 rebotes y vuela al display del ore.
func setup(spawn_pos: Vector2, data: OreData = null, amount: int = 1) -> void:
	ore_data = data
	pickup_amount = maxi(amount, 1)
	if ore_data != null and ore_data.currency_sprite != null:
		sprite.texture = ore_data.currency_sprite

	var offset := Vector2(
		randf_range(-cell_spawn_radius, cell_spawn_radius),
		randf_range(-cell_spawn_radius * 0.2, cell_spawn_radius * 0.2)
	)
	global_position = spawn_pos + offset
	scale = Vector2.ZERO

	var pop := create_tween()
	pop.tween_property(self, "scale", Vector2.ONE, 0.1).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	await play_drop_and_home()


func play_drop_and_home() -> void:
	var floor_y := global_position.y + drop_y_fall_amount
	var direction := -1.0 if randf() < 0.5 else 1.0
	var travel := direction * randf_range(lateral_bounce_spread * 0.7, lateral_bounce_spread)

	# Caida + 2 rebotes laterales.
	await move_to(Vector2(global_position.x + travel * 0.35, floor_y), fall_duration, Tween.EASE_IN)
	await move_to(Vector2(global_position.x + travel * 0.25, floor_y - first_bounce_height), bounce_up_duration, Tween.EASE_OUT)
	await move_to(Vector2(global_position.x + travel * 0.25, floor_y), fall_duration * 0.9, Tween.EASE_IN)
	await move_to(Vector2(global_position.x + travel * 0.15, floor_y - second_bounce_height), bounce_up_duration * 0.85, Tween.EASE_OUT)
	await move_to(Vector2(global_position.x + travel * 0.1, floor_y), fall_duration * 0.75, Tween.EASE_IN)

	await home_to_inventory_display()
	add_ore_to_inventory()
	queue_free()


func move_to(target: Vector2, duration: float, ease_type: Tween.EaseType) -> void:
	var tween := create_tween()
	tween.tween_property(self, "global_position", target, duration).set_trans(Tween.TRANS_QUAD).set_ease(ease_type)
	await tween.finished


## Curva suave hacia el icono del OreInventoryDisplay (pantalla → mundo).
func home_to_inventory_display() -> void:
	var inventory: Inventory = Refs.inventory
	inventory.prepare_incoming(ore_data)
	await get_tree().process_frame

	var screen_pos := inventory.get_ore_icon_center(ore_data.id)
	var world_pos := get_viewport().get_canvas_transform().affine_inverse() * screen_pos
	await Feedbacks.do_jump(self, global_position, world_pos, home_duration, home_arc_height)

	var shrink := create_tween()
	shrink.tween_property(self, "scale", Vector2.ZERO, 0.08).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	await shrink.finished
	inventory.pulse_ore_display(ore_data.id)


func add_ore_to_inventory() -> void:
	CurrencyManager.add_ore(ore_data, pickup_amount)
