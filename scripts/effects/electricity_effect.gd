extends Line2D
class_name ElectricityEffect
## Rayo estilo Rock Bottom: core blanco + glow, zigzag perp, flicker y flash de impacto.
## Effects.electricity() lo spawnea. ChainLightning solo pide el hop.

const CIRCLE := preload("res://Circle512.png")
const WIDTH_CURVE := preload("uid://w1uhupilwqcy")
const CORE_COLOR := Color(0.85, 0.95, 1.0, 1.0)
const FLASH_COLOR := Color(0.85, 0.95, 1.0, 1.0)
const JITTER_INTERVAL := 0.08
const SEGMENT_PX := 28.0
const AFTERIMAGE_FADE := 0.55

var to: Vector2
var points_width: float
var line_width: float
var glow: Line2D
var glow_tint: Color
var hold_duration: float = 0.28
var travel_duration: float = 0.1

var base_points: PackedVector2Array = PackedVector2Array()
var final_points: PackedVector2Array = PackedVector2Array()
var travel_timer: float = 0.0
var hold_timer: float = 0.0
var jitter_timer: float = 0.0
var is_traveling: bool = true
var shown_count: int = 0
var spark_lines: Array[Line2D] = []

## Compat: ChainLightning / Effects viejos llamaban add_inner. El glow ya cubre ese rol.
var inner: Line2D
var inner_width_ratio: float = 0.22


func _init(from: Vector2, _to: Vector2, color: Color, _line_width: float = 12.0, _points_width: float = 8.0) -> void:
	global_position = from
	to = _to
	line_width = _line_width
	points_width = maxf(_points_width, 8.0)
	glow_tint = color
	z_index = 50
	z_as_relative = false
	joint_mode = Line2D.LINE_JOINT_BEVEL
	begin_cap_mode = Line2D.LINE_CAP_ROUND
	end_cap_mode = Line2D.LINE_CAP_ROUND
	antialiased = true
	width = maxf(line_width * 0.22, 4.0)
	default_color = CORE_COLOR
	width_curve = WIDTH_CURVE


func _ready() -> void:
	setup_glow()
	build_base_path()
	apply_jitter()
	var dist := to_local(to).length()
	travel_duration = clampf(dist / 2200.0, 0.06, 0.14)
	show_prefix(2)
	spawn_impact_flash()
	spawn_spark_stubs()


func _process(delta: float) -> void:
	if is_traveling:
		tick_travel(delta)
		return
	tick_hold(delta)


func add_inner(inner_color: Color, _inner_width_ratio: float) -> void:
	inner_width_ratio = _inner_width_ratio
	if glow != null:
		glow.default_color = Color(inner_color.r, inner_color.g, inner_color.b, 0.4)
		return
	inner = glow


func update_effect() -> void:
	build_base_path()
	apply_jitter()
	show_prefix(maxi(shown_count, 2))


func set_line_width(lw: float) -> void:
	line_width = lw
	width = maxf(line_width * 0.22, 4.0)
	if glow != null:
		glow.width = line_width


func tween_width(end_width: float, duration: float) -> MethodTweener:
	var tween := create_tween()
	return tween.tween_method(set_line_width, line_width, end_width, duration).set_trans(Tween.TRANS_LINEAR)


func setup_glow() -> void:
	glow = Line2D.new()
	glow.width = line_width
	glow.default_color = Color(glow_tint.r, glow_tint.g, glow_tint.b, 0.38)
	glow.joint_mode = Line2D.LINE_JOINT_BEVEL
	glow.begin_cap_mode = Line2D.LINE_CAP_ROUND
	glow.end_cap_mode = Line2D.LINE_CAP_ROUND
	glow.antialiased = true
	glow.width_curve = WIDTH_CURVE
	glow.z_index = -1
	glow.show_behind_parent = true
	add_child(glow)
	inner = glow


func build_base_path() -> void:
	base_points = PackedVector2Array()
	var local_to := to_local(to)
	var distance := local_to.length()
	var mid_count := clampi(int(distance / SEGMENT_PX), 3, 12)
	base_points.append(Vector2.ZERO)
	for i in mid_count:
		var t := float(i + 1) / float(mid_count + 1)
		base_points.append(local_to * t)
	base_points.append(local_to)


## Zigzag alternado perpendicular al segmento (receta LightningArc de Rock Bottom).
func apply_jitter() -> void:
	final_points = PackedVector2Array()
	var last := base_points.size() - 1
	var side := 1.0
	for i in base_points.size():
		var point := base_points[i]
		if i > 0 and i < last:
			var prev := base_points[i - 1]
			var nxt := base_points[mini(i + 1, last)]
			var seg := (nxt - prev).normalized()
			if seg.length_squared() < 0.0001:
				seg = Vector2.RIGHT
			var perp := Vector2(-seg.y, seg.x)
			var amp := randf_range(points_width * 0.4, points_width)
			point += perp * amp * side
			point += seg * randf_range(-6.0, 6.0)
			side *= -1.0
		final_points.append(point)


func tick_travel(delta: float) -> void:
	travel_timer += delta
	var progress := clampf(travel_timer / maxf(travel_duration, 0.01), 0.0, 1.0)
	var want := clampi(int(ceil(progress * float(final_points.size()))), 2, final_points.size())
	if want > shown_count:
		show_prefix(want)
	if progress < 1.0:
		return
	is_traveling = false
	show_prefix(final_points.size())
	spawn_afterimage()


func tick_hold(delta: float) -> void:
	hold_timer += delta
	var alpha := 1.0 - hold_timer / maxf(hold_duration, 0.01)
	if alpha <= 0.0:
		queue_free()
		return
	default_color.a = alpha
	if glow != null:
		glow.default_color.a = alpha * alpha * 0.38
	for spark in spark_lines:
		if is_instance_valid(spark):
			spark.default_color.a = alpha * 0.65
	if hold_timer >= hold_duration * 0.5:
		return
	jitter_timer += delta
	if jitter_timer < JITTER_INTERVAL:
		return
	jitter_timer = 0.0
	apply_jitter()
	show_prefix(shown_count)


func show_prefix(count: int) -> void:
	shown_count = clampi(count, 2, final_points.size())
	var slice := PackedVector2Array()
	for i in shown_count:
		slice.append(final_points[i])
	points = slice
	if glow != null:
		glow.points = slice


func spawn_impact_flash() -> void:
	var flash := Sprite2D.new()
	flash.texture = CIRCLE
	flash.centered = true
	flash.position = to_local(to)
	flash.z_index = 2
	flash.modulate = FLASH_COLOR
	flash.scale = Vector2.ONE * 0.06
	add_child(flash)
	var tween := flash.create_tween().set_parallel(true)
	tween.tween_property(flash, "scale", Vector2.ONE * 0.22, 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(flash, "modulate:a", 0.0, 0.12)
	tween.chain().tween_callback(flash.queue_free)


## Trozos cortos que salen del trazo (sparks de LightningArc).
func spawn_spark_stubs() -> void:
	if final_points.size() < 4:
		return
	var spark_count := clampi(int(final_points.size() / 3.0), 2, 5)
	for i in spark_count:
		var idx := randi_range(1, final_points.size() - 2)
		var origin := final_points[idx]
		var dir := Vector2.RIGHT.rotated(randf() * TAU)
		var spark := Line2D.new()
		spark.width = maxf(line_width * 0.12, 2.5)
		spark.default_color = Color(CORE_COLOR.r, CORE_COLOR.g, CORE_COLOR.b, 0.7)
		spark.joint_mode = Line2D.LINE_JOINT_BEVEL
		spark.begin_cap_mode = Line2D.LINE_CAP_ROUND
		spark.end_cap_mode = Line2D.LINE_CAP_ROUND
		spark.points = PackedVector2Array([origin, origin + dir * randf_range(18.0, 42.0)])
		add_child(spark)
		spark_lines.append(spark)


func spawn_afterimage() -> void:
	var parent := get_parent()
	if parent == null or final_points.size() < 2:
		return
	var world_pts := PackedVector2Array()
	for point in final_points:
		world_pts.append(to_global(point))
	spawn_afterimage_line(parent, world_pts, line_width * 0.7, Color(glow_tint.r, glow_tint.g, glow_tint.b, 0.16))
	spawn_afterimage_line(parent, world_pts, maxf(line_width * 0.14, 2.0), Color(CORE_COLOR.r, CORE_COLOR.g, CORE_COLOR.b, 0.22))


func spawn_afterimage_line(parent: Node, world_pts: PackedVector2Array, line_w: float, color: Color) -> void:
	var ghost := Line2D.new()
	ghost.z_index = 49
	ghost.z_as_relative = false
	ghost.width = line_w
	ghost.default_color = color
	ghost.joint_mode = Line2D.LINE_JOINT_BEVEL
	ghost.begin_cap_mode = Line2D.LINE_CAP_ROUND
	ghost.end_cap_mode = Line2D.LINE_CAP_ROUND
	ghost.antialiased = true
	parent.add_child(ghost)
	for point in world_pts:
		ghost.add_point(point)
	var tween := ghost.create_tween()
	tween.tween_property(ghost, "modulate:a", 0.0, AFTERIMAGE_FADE).set_ease(Tween.EASE_IN)
	tween.tween_callback(ghost.queue_free)
