@tool
extends Node2D
## Mapa del arbol: pan (click derecho) y zoom (rueda) mueven este nodo. Sin Camera2D.

@export var edge_width := 3.0
@export var edge_color := Color.WHITE

@export_category("Zoom")
@export var zoom_min := 0.5
@export var zoom_max := 3.0
@export var zoom_step := 1.1
@export var default_zoom := 2.0


func _process(_delta):
	if Engine.is_editor_hint():
		queue_redraw()


func _draw():
	for node in $Nodes.get_children():
		if node.visible:
			if node.get("node1") and node.node1.visible:
				draw_edge(node, node.node1)
			if node.get("node2") and node.node2.visible:
				draw_edge(node, node.node2)


func draw_edge(node_a, node_b):
	draw_line(to_local(node_a.global_position), to_local(node_b.global_position), edge_color, edge_width, true)


## Centra el cluster de nodos en el panel al abrir.
func reset_view(panel_size: Vector2) -> void:
	scale = Vector2(default_zoom, default_zoom)
	position = panel_size * 0.5


## Pan y zoom. Solo lo llama UpgradeTree cuando el panel esta abierto.
func handle_map_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		if Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
			position += event.relative
			get_viewport().set_input_as_handled()
		return

	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			apply_zoom(zoom_step)
			get_viewport().set_input_as_handled()
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			apply_zoom(1.0 / zoom_step)
			get_viewport().set_input_as_handled()


## Zoom hacia el cursor, clamped a zoom_min / zoom_max.
func apply_zoom(factor: float) -> void:
	var old_scale = scale.x
	var new_scale = clampf(old_scale * factor, minf(zoom_min, zoom_max), maxf(zoom_min, zoom_max))
	if is_equal_approx(new_scale, old_scale):
		return
	var mouse = get_global_mouse_position()
	var local_point = (mouse - global_position) / old_scale
	scale = Vector2(new_scale, new_scale)
	global_position = mouse - local_point * new_scale
