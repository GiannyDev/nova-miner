@tool
extends Node2D
class_name MineGrid

@export var cell_size: int = 64 : set = set_cell_size
@export var grid_world_size: Vector2 = Vector2(5486, 3086) : set = set_grid_world_size
## Radio Chebyshev (en celdas) que se mantiene vacio alrededor del centro para el player.
@export var safe_zone_radius_cells: int = 3 : set = set_safe_zone_radius_cells

@export_group("Debug")
@export var show_grid: bool = true : set = set_show_grid
## Ancho en píxeles de pantalla. En Godot 4, valores negativos no escalan con el zoom.
@export var grid_line_width: float = -1.0 : set = set_grid_line_width
## Cada cuantas celdas se dibuja una linea mayor cuando el zoom esta alejado.
@export var major_grid_interval: int = 8 : set = set_major_grid_interval
## Si una celda ocupa menos que esto en pantalla, se salta lineas intermedias (LOD).
@export var min_cell_pixels: float = 10.0
@export var grid_color: Color = Color(1, 1, 1, 0.08) : set = set_grid_color
@export var major_grid_color: Color = Color(1, 1, 1, 0.2) : set = set_major_grid_color
@export var border_color: Color = Color(1, 1, 1, 0.35) : set = set_border_color
@export var safe_zone_color: Color = Color(0.3, 0.9, 0.4, 0.15)
@export var occupied_color: Color = Color(0.9, 0.4, 0.3, 0.35)

var occupied: Dictionary = {}
var _last_view_zoom: float = -1.0


func _ready() -> void:
	set_process(show_grid)
	queue_redraw()


func _unhandled_process(_delta: float) -> void:
	if not show_grid:
		return

	var zoom := get_view_zoom()
	if is_equal_approx(zoom, _last_view_zoom):
		return

	_last_view_zoom = zoom
	queue_redraw()


func _draw() -> void:
	if not show_grid:
		return

	draw_grid_lines()
	draw_safe_zone()
	draw_occupied_cells()


func draw_grid_lines() -> void:
	var dims := get_grid_dimensions()
	var total := Vector2(dims.x * cell_size, dims.y * cell_size)
	var origin := -total * 0.5
	var step := get_line_step()
	var line_width := get_draw_line_width()

	draw_axis_lines(origin, total, dims, step, grid_color, line_width)

	if step < major_grid_interval:
		draw_axis_lines(origin, total, dims, major_grid_interval, major_grid_color, line_width)

	draw_grid_border(origin, total, line_width)


func draw_axis_lines(
	origin: Vector2,
	total: Vector2,
	dims: Vector2i,
	step: int,
	color: Color,
	line_width: float
) -> void:
	var points := PackedVector2Array()

	for x in range(0, dims.x + 1, step):
		var px := origin.x + x * cell_size
		points.append(Vector2(px, origin.y))
		points.append(Vector2(px, origin.y + total.y))

	for y in range(0, dims.y + 1, step):
		var py := origin.y + y * cell_size
		points.append(Vector2(origin.x, py))
		points.append(Vector2(origin.x + total.x, py))

	if points.size() >= 2:
		draw_multiline(points, color, line_width, false)


func draw_grid_border(origin: Vector2, total: Vector2, line_width: float) -> void:
	var top_left := origin
	var top_right := origin + Vector2(total.x, 0.0)
	var bottom_right := origin + total
	var bottom_left := origin + Vector2(0.0, total.y)
	var border := PackedVector2Array([
		top_left, top_right,
		top_right, bottom_right,
		bottom_right, bottom_left,
		bottom_left, top_left,
	])
	draw_multiline(border, border_color, line_width, false)


func draw_safe_zone() -> void:
	var center := get_center_cell()
	var r := safe_zone_radius_cells
	for cy in range(center.y - r, center.y + r + 1):
		for cx in range(center.x - r, center.x + r + 1):
			var cell := Vector2i(cx, cy)
			if is_in_bounds(cell):
				draw_rect(get_cell_rect(cell), safe_zone_color)


func draw_occupied_cells() -> void:
	for cell in occupied:
		draw_rect(get_cell_rect(cell), occupied_color)


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


## Cuantas celdas saltar entre lineas segun el tamaño visible en pantalla.
func get_line_step() -> int:
	var cell_pixels := float(cell_size) * get_view_zoom()
	if cell_pixels >= min_cell_pixels:
		return 1
	if cell_pixels >= min_cell_pixels * 0.5:
		return 2
	if cell_pixels >= min_cell_pixels * 0.25:
		return 4
	return maxi(major_grid_interval, 8)


func get_draw_line_width() -> float:
	return grid_line_width if grid_line_width < 0.0 else maxf(grid_line_width, 1.001)


## Devuelve el numero de celdas del grid en X e Y.
func get_grid_dimensions() -> Vector2i:
	return Vector2i(int(grid_world_size.x) / cell_size, int(grid_world_size.y) / cell_size)


## Posicion mundo del centro de una celda (grid centrado en el origen).
func cell_to_world(cell: Vector2i) -> Vector2:
	var dims := get_grid_dimensions()
	var total := Vector2(dims.x * cell_size, dims.y * cell_size)
	var origin := -total * 0.5
	return origin + Vector2(cell.x + 0.5, cell.y + 0.5) * float(cell_size)


## Celda que contiene una posicion mundo.
func world_to_cell(pos: Vector2) -> Vector2i:
	var dims := get_grid_dimensions()
	var total := Vector2(dims.x * cell_size, dims.y * cell_size)
	var local := pos + total * 0.5
	return Vector2i(int(local.x / cell_size), int(local.y / cell_size))


func get_center_cell() -> Vector2i:
	return world_to_cell(Vector2.ZERO)


func get_cell_rect(cell: Vector2i) -> Rect2:
	var world := cell_to_world(cell)
	return Rect2(world - Vector2(cell_size, cell_size) * 0.5, Vector2(cell_size, cell_size))


func set_occupied(cell: Vector2i, value: bool) -> void:
	if value:
		occupied[cell] = true
	else:
		occupied.erase(cell)
	if show_grid:
		queue_redraw()


func clear_occupied() -> void:
	occupied.clear()
	if show_grid:
		queue_redraw()


func set_cell_size(value: int) -> void:
	cell_size = maxi(value, 1)
	queue_redraw()


func set_grid_world_size(value: Vector2) -> void:
	grid_world_size = value
	queue_redraw()


func set_safe_zone_radius_cells(value: int) -> void:
	safe_zone_radius_cells = maxi(value, 0)
	queue_redraw()


func set_show_grid(value: bool) -> void:
	show_grid = value
	set_process(value)
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


func set_border_color(value: Color) -> void:
	border_color = value
	queue_redraw()


func is_in_bounds(cell: Vector2i) -> bool:
	var dims := get_grid_dimensions()
	return cell.x >= 0 and cell.y >= 0 and cell.x < dims.x and cell.y < dims.y


func is_occupied(cell: Vector2i) -> bool:
	return occupied.has(cell)


func is_safe_cell(cell: Vector2i) -> bool:
	var center := get_center_cell()
	return maxi(absi(cell.x - center.x), absi(cell.y - center.y)) <= safe_zone_radius_cells


## Una celda es valida para spawnear ore si esta dentro, no es zona segura y esta libre.
func is_free_for_spawn(cell: Vector2i) -> bool:
	return is_in_bounds(cell) and not is_safe_cell(cell) and not is_occupied(cell)


## Comprueba que TODAS las celdas libres siguen conectadas al centro (player nunca queda atrapado).
func is_fully_accessible() -> bool:
	var dims := get_grid_dimensions()
	var expected_open := dims.x * dims.y - occupied.size()
	var start := get_center_cell()
	if is_occupied(start):
		return false

	var visited: Dictionary = {start: true}
	var stack: Array[Vector2i] = [start]
	var reached := 0
	var neighbors := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]

	while not stack.is_empty():
		var cell: Vector2i = stack.pop_back()
		reached += 1
		for offset in neighbors:
			var next: Vector2i = cell + offset
			if not is_in_bounds(next) or visited.has(next) or is_occupied(next):
				continue
			visited[next] = true
			stack.append(next)

	return reached == expected_open
