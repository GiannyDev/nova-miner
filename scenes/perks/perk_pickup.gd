extends Area2D
class_name PerkPickup
## Hueco 1x1 en la cueva. El player lo recorre y lo recoge. Marker de borde mientras exista.

signal collected(pickup: PerkPickup)

@onready var icon: Sprite2D = %Icon

var perk_data: PerkData
var grid_cell: Vector2i = Vector2i.ZERO
var is_taken: bool = false


func _ready() -> void:
	body_entered.connect(_on_body_entered)


func setup(data: PerkData, cell: Vector2i, world_pos: Vector2) -> void:
	perk_data = data
	grid_cell = cell
	global_position = world_pos
	if data != null and data.icon != null:
		icon.texture = data.icon


func get_marker_world_pos() -> Vector2:
	return global_position


func get_marker_icon() -> Texture2D:
	return perk_data.icon if perk_data != null else null


func is_marker_active() -> bool:
	return not is_taken and is_inside_tree()


func _on_body_entered(body: Node) -> void:
	if is_taken or body == null:
		return
	if body is Player or body.is_in_group("player"):
		collect()


func collect() -> void:
	if is_taken or perk_data == null:
		return
	is_taken = true
	if Refs.mine_zone != null:
		Refs.mine_zone.add_perk(perk_data)
	collected.emit(self)
	queue_free()
