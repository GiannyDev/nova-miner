extends Line2D
class_name UpgradeLine

var from_button: Control
var to_button: Control
var grow_progress: float = 1.0
## Si true, usa endpoints fijos (reveal) para que scale/rotacion del nodo no tuerza la linea.
var lock_endpoints: bool = false
var locked_point_a: Vector2 = Vector2.ZERO
var locked_point_b: Vector2 = Vector2.ZERO


func _process(_delta: float) -> void:
	if from_button == null or to_button == null:
		return

	clear_points()
	var point_a: Vector2
	var point_b: Vector2
	if lock_endpoints:
		point_a = locked_point_a
		point_b = locked_point_b
	else:
		point_a = to_local(from_button.get_global_rect().get_center())
		point_b = to_local(to_button.get_global_rect().get_center())

	if grow_progress < 1.0:
		point_b = point_a.lerp(point_b, grow_progress)
	add_point(point_a)
	add_point(point_b)


func apply_style(width: float, color: Color, cap_mode: Line2D.LineCapMode) -> void:
	self.width = width
	default_color = color
	begin_cap_mode = cap_mode
	end_cap_mode = cap_mode


func reset_grow() -> void:
	grow_progress = 0.0
	visible = false
	clear_endpoint_lock()


## Fija los extremos al centro en reposo de cada nodo (ignora scale/rotacion en vivo).
func lock_to_rest_centers(from_rest_global: Vector2, to_rest_global: Vector2) -> void:
	lock_endpoints = true
	locked_point_a = to_local(from_rest_global)
	locked_point_b = to_local(to_rest_global)


func clear_endpoint_lock() -> void:
	lock_endpoints = false
