extends RayCast2D
class_name LaserWeapon

@export var cast_speed: float = 7000.0
@export var max_length: float = 400.0
@export var growth_time: float = 0.1
@export var color: Color = Color.WHITE: set = set_color
@export var line_width: float = 4.0

@onready var line: Line2D = $Line2D
@onready var fire_pos: Marker2D = $"../LaserFirePos"

var is_casting: bool = false: set = set_is_casting
var width_tween: Tween


func _ready() -> void:
	set_color(color)
	disappear(false)
	set_physics_process(false)
	collision_mask = 2 ## Layer Ore
	collide_with_areas = false
	collide_with_bodies = true


func set_is_casting(active: bool) -> void:
	if is_casting == active:
		return

	is_casting = active
	set_physics_process(is_casting)

	if is_casting:
		target_position = Vector2.ZERO
		appear()
	else:
		target_position = Vector2.ZERO
		disappear(true)


func set_color(new_color: Color) -> void:
	color = new_color
	if line != null:
		line.modulate = new_color


func set_max_length(length: float) -> void:
	max_length = maxf(length, 1.0)


## Ore impactado este frame, o null.
func get_hit_ore() -> Ore:
	if not is_casting or not is_colliding():
		return null
	return resolve_ore(get_collider())


func _physics_process(delta: float) -> void:
	target_position.x = move_toward(target_position.x, max_length, cast_speed * delta)
	force_raycast_update()
	update_beam_visual()


func update_beam_visual() -> void:
	ensure_line_points()

	var local_start := to_local(fire_pos.global_position) if fire_pos else Vector2.ZERO
	var local_end: Vector2 = to_local(get_collision_point()) if is_colliding() else target_position

	line.set_point_position(0, local_start)
	line.set_point_position(1, local_end)


func appear() -> void:
	ensure_line_points()
	line.visible = true
	kill_width_tween()
	width_tween = create_tween()
	width_tween.tween_property(line, "width", line_width, growth_time * 2.0).from(0.0)


func disappear(animate: bool) -> void:
	kill_width_tween()

	if not animate or line == null:
		if line != null:
			line.width = 0.0
			line.clear_points()
			line.hide()
		return

	width_tween = create_tween()
	width_tween.tween_property(line, "width", 0.0, growth_time).from_current()
	width_tween.tween_callback(func() -> void:
		line.clear_points()
		line.hide()
	)


func ensure_line_points() -> void:
	if line.points.size() >= 2:
		return
	line.clear_points()
	line.add_point(Vector2.ZERO)
	line.add_point(Vector2.ZERO)


func kill_width_tween() -> void:
	if width_tween != null and width_tween.is_valid():
		width_tween.kill()
	width_tween = null


func resolve_ore(collider: Object) -> Ore:
	if collider == null:
		return null
	if collider is Ore:
		return collider as Ore
	if collider is Node:
		return (collider as Node).get_parent() as Ore
	return null
