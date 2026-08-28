extends Control
class_name OffscreenMarkerLayer
## Iconos pegados al borde del viewport. Contrato: get_marker_world_pos / get_marker_icon / is_marker_active.

const MARKER_SCENE := preload("res://scenes/ui/offscreen_marker/offscreen_marker.tscn")

@export var edge_margin: float = 36.0
@export var onscreen_padding: float = 48.0
@export var marker_size: Vector2 = Vector2(64, 64)

var targets: Array[Node] = []
var markers: Dictionary = {}


func _process(_delta: float) -> void:
	refresh_markers()


func register_target(target: Node) -> void:
	if target == null or targets.has(target):
		return
	targets.append(target)
	var marker := MARKER_SCENE.instantiate() as OffscreenMarker
	add_child(marker)
	marker.size = marker_size
	marker.hide()
	markers[target] = marker
	if target.has_signal("tree_exiting"):
		if not target.tree_exiting.is_connected(_on_target_exiting):
			target.tree_exiting.connect(_on_target_exiting.bind(target))


func unregister_target(target: Node) -> void:
	if target == null:
		return
	targets.erase(target)
	var marker: OffscreenMarker = markers.get(target) as OffscreenMarker
	markers.erase(target)
	if is_instance_valid(marker):
		marker.queue_free()


func clear_targets() -> void:
	var snapshot := targets.duplicate()
	for target in snapshot:
		unregister_target(target)


func refresh_markers() -> void:
	var cam := Refs.camera
	if cam == null:
		return
	var viewport_size := get_viewport_rect().size
	var inner := Rect2(Vector2(onscreen_padding, onscreen_padding), viewport_size - Vector2(onscreen_padding, onscreen_padding) * 2.0)
	var edge := Rect2(Vector2(edge_margin, edge_margin), viewport_size - Vector2(edge_margin, edge_margin) * 2.0)
	edge.size -= marker_size
	var canvas := cam.get_viewport().get_canvas_transform()
	var stale: Array[Node] = []
	for target in targets:
		if not is_instance_valid(target) or not target.has_method("is_marker_active") or not target.is_marker_active():
			stale.append(target)
			continue
		var marker: OffscreenMarker = markers.get(target) as OffscreenMarker
		if marker == null:
			continue
		var world_pos: Vector2 = target.get_marker_world_pos()
		var screen: Vector2 = canvas * world_pos
		if inner.has_point(screen):
			marker.hide()
			continue
		marker.show()
		if target.has_method("get_marker_icon"):
			marker.set_icon(target.get_marker_icon())
		var edge_pos := clamp_to_rect(screen, edge)
		marker.position = edge_pos
	for target in stale:
		unregister_target(target)


func clamp_to_rect(point: Vector2, rect: Rect2) -> Vector2:
	var center := rect.get_center()
	var dir := point - center
	if dir.length_squared() < 0.001:
		return center
	var t := INF
	if not is_zero_approx(dir.x):
		if dir.x > 0.0:
			t = minf(t, (rect.end.x - center.x) / dir.x)
		else:
			t = minf(t, (rect.position.x - center.x) / dir.x)
	if not is_zero_approx(dir.y):
		if dir.y > 0.0:
			t = minf(t, (rect.end.y - center.y) / dir.y)
		else:
			t = minf(t, (rect.position.y - center.y) / dir.y)
	if not is_finite(t):
		return center
	return center + dir * t


func _on_target_exiting(target: Node) -> void:
	unregister_target(target)
