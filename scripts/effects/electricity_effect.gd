extends Line2D
class_name ElectricityEffect

var to: Vector2

# Max width for randomized placement of points
var points_width: float
var line_width: float

var inner: Line2D
var inner_width_ratio: float

func _init(from: Vector2, _to: Vector2, color: Color, _line_width: float = 12.0, _points_width: float = 8.0) -> void:
	global_position = from
	to = _to
	line_width = _line_width
	points_width = _points_width
	default_color = color
	width = line_width
	width_curve = preload("uid://w1uhupilwqcy")


func _ready() -> void:
	update_effect()


func add_inner(inner_color: Color, _inner_width_ratio: float) -> void:
	inner = Line2D.new()
	add_child(inner)
	inner.default_color = inner_color
	inner_width_ratio = _inner_width_ratio
	inner.width = width * inner_width_ratio
	inner.points = points
	inner.width_curve = width_curve


func update_effect() -> void:
	var from = Vector2.ZERO
	var local_to = to_local(to)
	
	var direction: Vector2 = (local_to - from).normalized()
	var perp: Vector2 = direction.orthogonal()
	
	var distance := from.distance_to(local_to)
	var num_vertices = 1 + int(ceil(distance / 15.0))
	
	var new_points: Array = []
	new_points.resize(2 + num_vertices)
	
	new_points[0] = from
	
	var distances = []
	distances.resize(num_vertices)
	
	for i in range(distances.size()):
		var prev_dist = (distance / num_vertices) * 1
		var this_dist = prev_dist + (distance / num_vertices) * randf_range(0.7, 1.3)
		distances[i] = this_dist
		
		var point = from + this_dist * direction
		point += perp * randf_range(-(points_width + 6), (points_width + 6))
		
		new_points[i + 1] = point
	
	new_points[-1] = local_to
	points = new_points
	if inner:
		inner.points = points


func set_line_width(lw: float) -> void:
	line_width = lw
	width = line_width
	if inner:
		inner.width = width * inner_width_ratio


func tween_width(end_width: float, duration: float) -> MethodTweener:
	var tween := create_tween()
	return tween.tween_method(set_line_width, line_width, end_width, duration).set_trans(Tween.TRANS_LINEAR)
