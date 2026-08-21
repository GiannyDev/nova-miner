@tool
extends Node2D
class_name MineGrid
## Espacio de celdas infinito de la mina: conversion celda<->mundo, ocupacion, reservas y debug draw.
## No decide WHERE (chunk) ni el contenido persistente (OreSpawner generate-once).
## Asume el nodo sin transform propio (position 0, sin rotar ni escalar).

## Tamano de celda en pixeles (X = ancho de footprint, Y = paso de stack). Lo dicta block_layout.
@export var cell_size: Vector2i = Vector2i(256, 158) : set = set_cell_size
## Sprite del bloque + cell_size + offset de asiento. Fuente de verdad compartida con OreSpawner.
@export var block_layout: MineBlockLayout : set = set_block_layout

@export_group("Debug")
@export var show_grid: bool = true : set = set_show_grid
## Celdas extra dibujadas alrededor de la pantalla para no ver el borde del dibujo.
@export var draw_padding_cells: int = 2
## Ancho en pixeles de pantalla. Negativo = no escala con el zoom.
@export var grid_line_width: float = -1.0 : set = set_grid_line_width
## Cada cuantas celdas se dibuja una linea mayor cuando el zoom esta alejado.
@export var major_grid_interval: int = 8 : set = set_major_grid_interval
## Si el lado menor de la celda ocupa menos que esto en pantalla, se saltan lineas (LOD).
@export var min_cell_pixels: float = 10.0
## Pinta celdas ocupadas y reservadas. Recorre los diccionarios completos: solo para debug.
@export var show_cell_states: bool = false : set = set_show_cell_states
@export var grid_color: Color = Color(1, 1, 1, 0.08) : set = set_grid_color
@export var major_grid_color: Color = Color(1, 1, 1, 0.2) : set = set_major_grid_color
@export var occupied_color: Color = Color(0.9, 0.4, 0.3, 0.35)
@export var reserved_color: Color = Color(0.3, 0.9, 0.4, 0.15)

# --- Runtime ---
var occupied: Dictionary = {}
var reserved: Dictionary = {}
var last_drawn_cell_rect: Rect2i = Rect2i()
var last_view_zoom: float = -1.0


# --- Built-ins ---
func _ready() -> void:
	ensure_block_layout()
	sync_cell_size_from_layout()
	set_process(show_grid)
	queue_redraw()


## Solo redibuja cuando cambia el rango de celdas visible o el zoom: nada de redraw por frame.
func _process(_delta: float) -> void:
	if not show_grid:
		return

	var zoom := get_view_zoom()
	var cell_rect := get_visible_cell_rect()
	if is_equal_approx(zoom, last_view_zoom) and cell_rect == last_drawn_cell_rect:
		return

	last_view_zoom = zoom
	queue_redraw()


func _draw() -> void:
	if not show_grid:
		return

	var cell_rect := get_visible_cell_rect()
	if cell_rect.size == Vector2i.ZERO:
		return

	last_drawn_cell_rect = cell_rect
	draw_grid_lines(cell_rect)

	if show_cell_states:
		draw_cell_states(cell_rect)


func _get_configuration_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()
	if not position.is_zero_approx() or not scale.is_equal_approx(Vector2.ONE) or not is_zero_approx(rotation):
		warnings.append("MineGrid asume transform identidad: dejalo en position 0, scale 1 y sin rotacion.")
	return warnings


# --- Public API ---
## Centro mundo de una celda. La celda (0,0) queda centrada en el origen del mundo.
func cell_to_world(cell: Vector2i) -> Vector2:
	return Vector2(cell) * Vector2(cell_size)


## Celda que contiene una posicion mundo. Usa round para que funcione con celdas negativas.
func world_to_cell(pos: Vector2) -> Vector2i:
	return Vector2i(
		roundi(pos.x / float(cell_size.x)),
		roundi(pos.y / float(cell_size.y))
	)


## Posicion mundo del OreBlock: centro de celda + offset de asiento + rise por stack_index.
func get_ore_world_position(cell: Vector2i, stack_index: int = 0) -> Vector2:
	ensure_block_layout()
	return cell_to_world(cell) + block_layout.get_stack_offset(stack_index)


func get_cell_rect(cell: Vector2i) -> Rect2:
	var size := Vector2(cell_size)
	return Rect2(cell_to_world(cell) - size * 0.5, size)


## Extension en pixeles de un rango de celdas (util para dibujar ventanas del chunk).
func cells_to_pixels(cells: Vector2i) -> Vector2:
	return Vector2(cells) * Vector2(cell_size)


func get_block_size() -> Vector2i:
	ensure_block_layout()
	return block_layout.get_block_size()


func get_stack_rise_y() -> float:
	ensure_block_layout()
	return block_layout.get_stack_rise_y()


func get_cell_center_offset_y() -> float:
	ensure_block_layout()
	return block_layout.cell_center_offset_y


func get_cell_width() -> int:
	return cell_size.x


func get_cell_height() -> int:
	return cell_size.y


## Zoom efectivo del viewport (editor o Camera2D en runtime).
func get_view_zoom() -> float:
	var viewport := get_viewport()
	if viewport == null:
		return 1.0

	if Engine.is_editor_hint():
		return viewport.global_canvas_transform.get_scale().x

	var camera := viewport.get_camera_2d()
	if camera != null:
		return camera.zoom.x

	return viewport.global_canvas_transform.get_scale().x


## Rect mundo que se esta viendo en pantalla (funciona en editor y en runtime).
func get_visible_world_rect() -> Rect2:
	var viewport := get_viewport()
	if viewport == null:
		return Rect2()

	var xform := viewport.global_canvas_transform
	var view_scale := xform.get_scale()
	if is_zero_approx(view_scale.x) or is_zero_approx(view_scale.y):
		return Rect2()

	var top_left := -xform.origin / view_scale
	return Rect2(top_left, viewport.get_visible_rect().size / view_scale)


## Rango de celdas visible (+ padding). Base del dibujo de debug.
func get_visible_cell_rect() -> Rect2i:
	var world_rect := get_visible_world_rect()
	if world_rect.size.is_zero_approx():
		return Rect2i()

	var padding := Vector2i(draw_padding_cells, draw_padding_cells)
	var min_cell := world_to_cell(world_rect.position) - padding
	var max_cell := world_to_cell(world_rect.end) + padding
	return Rect2i(min_cell, max_cell - min_cell + Vector2i.ONE)


## Cuantas celdas saltar entre lineas segun el lado menor visible en pantalla.
func get_line_step() -> int:
	var min_side := float(mini(cell_size.x, cell_size.y))
	var cell_pixels := min_side * get_view_zoom()
	if cell_pixels >= min_cell_pixels:
		return 1
	if cell_pixels >= min_cell_pixels * 0.5:
		return 2
	if cell_pixels >= min_cell_pixels * 0.25:
		return 4
	return maxi(major_grid_interval, 8)


func get_draw_line_width() -> float:
	return grid_line_width if grid_line_width < 0.0 else maxf(grid_line_width, 1.001)


## Bloques apilados en la celda (0 = libre).
func get_stack_height(cell: Vector2i) -> int:
	return int(occupied.get(cell, 0))


## Marca celda ocupada. Con stacks, usa add_stack_occupation / remove_stack_occupation.
func set_occupied(cell: Vector2i, value: bool) -> void:
	if value:
		occupied[cell] = maxi(get_stack_height(cell), 1)
	else:
		occupied.erase(cell)
	request_state_redraw()


## Suma un bloque al stack de la celda (varios ores, una sola footprint).
func add_stack_occupation(cell: Vector2i) -> void:
	occupied[cell] = get_stack_height(cell) + 1
	request_state_redraw()


## Quita un bloque del stack; libera la celda solo cuando llega a 0.
func remove_stack_occupation(cell: Vector2i) -> void:
	if not occupied.has(cell):
		return

	var remaining := get_stack_height(cell) - 1
	if remaining <= 0:
		occupied.erase(cell)
	else:
		occupied[cell] = remaining
	request_state_redraw()


## Reserva permanente: celdas que nunca deben recibir ore (spawn del player, taladros, props).
func reserve_cell(cell: Vector2i) -> void:
	reserved[cell] = true
	request_state_redraw()


func release_cell(cell: Vector2i) -> void:
	reserved.erase(cell)
	request_state_redraw()


## Reserva un cuadrado Chebyshev de celdas alrededor de un centro.
func reserve_area(center: Vector2i, radius_cells: int) -> void:
	for cy in range(center.y - radius_cells, center.y + radius_cells + 1):
		for cx in range(center.x - radius_cells, center.x + radius_cells + 1):
			reserved[Vector2i(cx, cy)] = true
	request_state_redraw()


func release_area(center: Vector2i, radius_cells: int) -> void:
	for cy in range(center.y - radius_cells, center.y + radius_cells + 1):
		for cx in range(center.x - radius_cells, center.x + radius_cells + 1):
			reserved.erase(Vector2i(cx, cy))
	request_state_redraw()


func clear_occupied() -> void:
	occupied.clear()
	request_state_redraw()


## Vacia ocupacion y reservas (nueva run).
func reset() -> void:
	occupied.clear()
	reserved.clear()
	request_state_redraw()


# --- Private helpers (no leading _) ---
func ensure_block_layout() -> void:
	if block_layout == null:
		block_layout = MineBlockLayout.new()


## Copia cell_size XY desde el layout (fuente de verdad del diseno).
func sync_cell_size_from_layout() -> void:
	ensure_block_layout()
	if cell_size != block_layout.cell_size:
		cell_size = block_layout.cell_size


## Redraw solo si el debug de estados esta encendido (evita redraws en el hot path de spawn).
func request_state_redraw() -> void:
	if show_grid and show_cell_states:
		queue_redraw()


func draw_grid_lines(cell_rect: Rect2i) -> void:
	var step := get_line_step()
	var line_width := get_draw_line_width()

	draw_axis_lines(cell_rect, step, grid_color, line_width)

	if step < major_grid_interval:
		draw_axis_lines(cell_rect, major_grid_interval, major_grid_color, line_width)


## Dibuja lineas en los bordes de celda, alineadas al enrejado global segun step.
func draw_axis_lines(cell_rect: Rect2i, step: int, color: Color, line_width: float) -> void:
	var points := PackedVector2Array()
	var half := Vector2(cell_size) * 0.5
	var start := cell_to_world(cell_rect.position) - half
	var end := cell_to_world(cell_rect.end) - half

	var first_x := floori(float(cell_rect.position.x) / float(step)) * step
	for cx in range(first_x, cell_rect.end.x + 1, step):
		var px := cell_to_world(Vector2i(cx, 0)).x - half.x
		points.append(Vector2(px, start.y))
		points.append(Vector2(px, end.y))

	var first_y := floori(float(cell_rect.position.y) / float(step)) * step
	for cy in range(first_y, cell_rect.end.y + 1, step):
		var py := cell_to_world(Vector2i(0, cy)).y - half.y
		points.append(Vector2(start.x, py))
		points.append(Vector2(end.x, py))

	if points.size() >= 2:
		draw_multiline(points, color, line_width, false)


## Debug: pinta ocupadas y reservadas dentro del rango visible.
func draw_cell_states(cell_rect: Rect2i) -> void:
	for cell in occupied:
		if cell_rect.has_point(cell):
			draw_rect(get_cell_rect(cell), occupied_color)

	for cell in reserved:
		if cell_rect.has_point(cell):
			draw_rect(get_cell_rect(cell), reserved_color)


# --- Bool queries ---
func is_occupied(cell: Vector2i) -> bool:
	return occupied.has(cell)


func is_reserved(cell: Vector2i) -> bool:
	return reserved.has(cell)


## Una celda sirve para spawnear si no tiene bloques ni esta reservada.
func is_free_for_spawn(cell: Vector2i) -> bool:
	return not occupied.has(cell) and not reserved.has(cell)


# --- Setters ---
func set_cell_size(value: Vector2i) -> void:
	cell_size = Vector2i(maxi(value.x, 1), maxi(value.y, 1))
	queue_redraw()


func set_block_layout(value: MineBlockLayout) -> void:
	block_layout = value
	if block_layout != null and cell_size != block_layout.cell_size:
		cell_size = block_layout.cell_size
	queue_redraw()


func set_show_grid(value: bool) -> void:
	show_grid = value
	set_process(value)
	queue_redraw()


func set_show_cell_states(value: bool) -> void:
	show_cell_states = value
	queue_redraw()


func set_draw_padding_cells(value: int) -> void:
	draw_padding_cells = maxi(value, 1)
	queue_redraw()


func set_grid_line_width(value: float) -> void:
	grid_line_width = value
	queue_redraw()


func set_major_grid_interval(value: int) -> void:
	major_grid_interval = maxi(value, 1)
	queue_redraw()


func set_grid_color(value: Color) -> void:
	grid_color = value
	queue_redraw()


func set_major_grid_color(value: Color) -> void:
	major_grid_color = value
	queue_redraw()
