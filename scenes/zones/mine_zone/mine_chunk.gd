@tool
extends Node2D
class_name MineChunk
## Ventana movil de spawn: define en celdas la region valida donde el OreSpawner puede colocar ores.
## Solo sigue al player; no instancia ni decide cuando spawnear (eso es del spawner + upgrades).

## Se emite cada vez que la ventana se recentra sobre el target.
signal on_window_moved(window_cells: Rect2i)
## La ventana cambio de tamano (upgrades, skills o tuneo en el editor).
signal on_chunk_resized(size_cells: Vector2i)

const MIN_SIZE_CELLS := 1

# --- Exports ---
@export_category("Chunk")
## Grid que define el tamano de celda. Si lo dejas vacio toma el MineGrid hermano.
@export var grid: MineGrid
## Cuantos ores caben en la ventana en X e Y. Los pixeles salen solos del cell_size del grid.
@export var chunk_size_cells: Vector2i = Vector2i(21, 20) : set = set_chunk_size_cells
## Celdas que la ventana se adelanta hacia donde se mueve el player (evita ver aparecer ores).
@export var lookahead_cells: Vector2 = Vector2(3.0, 3.0)
## Celdas que debe recorrer el player antes de recalcular la ventana (dead-zone).
@export var refresh_step_cells: int = 1

@export_category("Upgrades")
## Stat del UpgradeTree que suma celdas a la ventana (vacio = sin bonus).
@export var size_bonus_stat: String = "chunk_size_bonus_cells"
## Como se reparte ese bonus entre X e Y (las celdas no son cuadradas).
@export var size_bonus_ratio: Vector2 = Vector2(1.0, 1.0)

@export_category("Debug")
@export var show_window: bool = true : set = set_show_window
@export var window_color: Color = Color(0.4, 0.8, 1.0, 0.5)
## Dibuja lo que realmente ve la camara: si sobresale de la ventana, veras aparecer ores.
@export var show_camera_view: bool = true : set = set_show_camera_view
@export var camera_view_color: Color = Color(1.0, 0.85, 0.3, 0.35)
## Zoom asumido para previsualizar la vista de camara en el editor.
@export var editor_preview_zoom: float = 0.5
@export var debug_line_width: float = 6.0

# --- Runtime ---
var follow_target: Node2D
var window_cells: Rect2i = Rect2i()
var effective_size_cells: Vector2i = Vector2i.ONE
var size_modifiers: Dictionary = {}
var next_modifier_expiry: float = INF
var last_center_cell: Vector2i = Vector2i.ZERO
var has_window: bool = false
var grid_lookup_done: bool = false


# --- Built-ins ---
func _ready() -> void:
	ensure_grid()
	refresh_size()
	set_physics_process(not Engine.is_editor_hint())
	queue_redraw()


## Sigue al target con dead-zone: solo trabaja cuando cruza refresh_step_cells.
func _physics_process(_delta: float) -> void:
	expire_size_modifiers()

	if follow_target == null or grid == null:
		return

	var center := get_target_center_cell()
	if not needs_refresh(center):
		return

	update_window(center)


func _draw() -> void:
	ensure_grid()
	if grid == null:
		return

	if show_window:
		draw_cell_rect_outline(get_draw_window(), window_color)

	if show_camera_view:
		draw_rect(get_camera_view_rect(), camera_view_color, false, debug_line_width)


func _get_configuration_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()
	ensure_grid()

	if grid == null:
		warnings.append("Asigna el MineGrid: el chunk necesita su cell_size para trabajar en celdas.")
		return warnings

	var view_cells := get_camera_view_cells()
	if chunk_size_cells.x <= view_cells.x or chunk_size_cells.y <= view_cells.y:
		warnings.append(
			"La ventana (%d x %d celdas) no cubre la vista de camara (%d x %d celdas): los ores van a aparecer en pantalla. Subi chunk_size_cells." \
			% [chunk_size_cells.x, chunk_size_cells.y, view_cells.x, view_cells.y]
		)

	return warnings


# --- Public API ---
## Empieza a seguir al player (o a cualquier Node2D) y centra la ventana de una.
func follow(target: Node2D) -> void:
	follow_target = target
	if follow_target == null or grid == null:
		return
	update_window(get_target_center_cell())


## Nueva run: limpia modificadores activos y la ventana.
func reset() -> void:
	size_modifiers.clear()
	next_modifier_expiry = INF
	has_window = false
	refresh_size()


## Agranda la ventana temporalmente (skills de velocidad/dash). duration <= 0 = hasta removerlo.
func add_size_modifier(id: StringName, extra_cells: Vector2i, duration: float = 0.0) -> void:
	var expires_at := INF
	if duration > 0.0:
		expires_at = get_now() + duration
		next_modifier_expiry = minf(next_modifier_expiry, expires_at)

	size_modifiers[id] = {"cells": extra_cells, "expires_at": expires_at}
	refresh_size()


func remove_size_modifier(id: StringName) -> void:
	if size_modifiers.erase(id):
		refresh_size()


## Recalcula el tamano efectivo (base + upgrades + skills) y recentra si ya habia ventana.
func refresh_size() -> void:
	var raw := chunk_size_cells + get_stat_bonus_cells() + get_modifier_cells()
	var clamped := Vector2i(maxi(raw.x, MIN_SIZE_CELLS), maxi(raw.y, MIN_SIZE_CELLS))
	if clamped == effective_size_cells:
		return

	effective_size_cells = clamped
	on_chunk_resized.emit(effective_size_cells)

	if has_window:
		update_window(last_center_cell)
	else:
		queue_redraw()


## Ventana a dibujar: la real en runtime, una centrada en el origen para previsualizar en editor.
func get_draw_window() -> Rect2i:
	if has_window:
		return window_cells
	return Rect2i(-effective_size_cells / 2, effective_size_cells)


## Rect mundo que ve la camara, para comparar contra la ventana.
func get_camera_view_rect() -> Rect2:
	var size := get_camera_view_size()
	var center := Vector2.ZERO
	if follow_target != null:
		center = follow_target.global_position
	return Rect2(center - size * 0.5, size)


func get_camera_view_size() -> Vector2:
	if Engine.is_editor_hint():
		return get_project_viewport_size() / maxf(editor_preview_zoom, 0.01)

	var viewport := get_viewport()
	if viewport == null:
		return get_project_viewport_size()

	var camera := viewport.get_camera_2d()
	if camera == null:
		return viewport.get_visible_rect().size

	return viewport.get_visible_rect().size / camera.zoom


## Vista de camara expresada en celdas (para el warning del Inspector).
func get_camera_view_cells() -> Vector2i:
	var size := get_camera_view_size()
	return Vector2i(
		ceili(size.x / float(grid.get_cell_width())),
		ceili(size.y / float(grid.get_cell_height()))
	)


# --- Private helpers (no leading _) ---
## Resuelve el grid una sola vez: el asignado o el primer MineGrid hermano.
func ensure_grid() -> void:
	if grid != null or grid_lookup_done:
		return

	grid_lookup_done = true
	var parent := get_parent()
	if parent == null:
		grid_lookup_done = false
		return

	for child in parent.get_children():
		if child is MineGrid:
			grid = child as MineGrid
			return


## Celda central de la ventana: celda del target mas el lookahead en su direccion de movimiento.
func get_target_center_cell() -> Vector2i:
	var cell := grid.world_to_cell(follow_target.global_position)
	var direction := get_target_direction()
	if direction == Vector2.ZERO:
		return cell

	return cell + Vector2i(
		roundi(direction.x * lookahead_cells.x),
		roundi(direction.y * lookahead_cells.y)
	)


## Direccion normalizada del target; Vector2.ZERO si esta quieto o no expone velocity.
func get_target_direction() -> Vector2:
	if follow_target is CharacterBody2D:
		var body := follow_target as CharacterBody2D
		if body.velocity.length_squared() > 1.0:
			return body.velocity.normalized()
	return Vector2.ZERO


func update_window(center_cell: Vector2i) -> void:
	last_center_cell = center_cell
	has_window = true
	window_cells = Rect2i(center_cell - effective_size_cells / 2, effective_size_cells)

	on_window_moved.emit(window_cells)

	if show_window or show_camera_view:
		queue_redraw()


## Celdas extra que vienen del UpgradeTree.
func get_stat_bonus_cells() -> Vector2i:
	if Engine.is_editor_hint() or size_bonus_stat.is_empty():
		return Vector2i.ZERO
	if GameManager.player_stats == null:
		return Vector2i.ZERO

	var bonus := GameManager.player_stats.get_stat(size_bonus_stat)
	return Vector2i(roundi(bonus * size_bonus_ratio.x), roundi(bonus * size_bonus_ratio.y))


func get_modifier_cells() -> Vector2i:
	var total := Vector2i.ZERO
	for id in size_modifiers:
		total += size_modifiers[id]["cells"] as Vector2i
	return total


## Saca modificadores vencidos. Solo recorre el diccionario cuando toca un vencimiento.
func expire_size_modifiers() -> void:
	if size_modifiers.is_empty():
		return

	var now := get_now()
	if now < next_modifier_expiry:
		return

	next_modifier_expiry = INF
	var expired: Array[StringName] = []

	for id in size_modifiers:
		var expires_at: float = size_modifiers[id]["expires_at"]
		if expires_at <= now:
			expired.append(id)
		else:
			next_modifier_expiry = minf(next_modifier_expiry, expires_at)

	for id in expired:
		size_modifiers.erase(id)

	if not expired.is_empty():
		refresh_size()


func get_now() -> float:
	return float(Time.get_ticks_msec()) / 1000.0


func get_project_viewport_size() -> Vector2:
	return Vector2(
		float(ProjectSettings.get_setting("display/window/size/viewport_width", 1920)),
		float(ProjectSettings.get_setting("display/window/size/viewport_height", 1080))
	)


func draw_cell_rect_outline(cell_rect: Rect2i, color: Color) -> void:
	var half := Vector2(grid.cell_size) * 0.5
	var world_rect := Rect2(grid.cell_to_world(cell_rect.position) - half, grid.cells_to_pixels(cell_rect.size))
	draw_rect(world_rect, color, false, debug_line_width)


# --- Bool queries ---
func needs_refresh(center_cell: Vector2i) -> bool:
	if not has_window:
		return true
	var step := maxi(refresh_step_cells, 1)
	return absi(center_cell.x - last_center_cell.x) >= step or absi(center_cell.y - last_center_cell.y) >= step


func is_inside_window(cell: Vector2i) -> bool:
	return has_window and window_cells.has_point(cell)


# --- Setters ---
func set_chunk_size_cells(value: Vector2i) -> void:
	chunk_size_cells = Vector2i(maxi(value.x, MIN_SIZE_CELLS), maxi(value.y, MIN_SIZE_CELLS))
	refresh_size()
	queue_redraw()
	if Engine.is_editor_hint():
		update_configuration_warnings()


func set_show_window(value: bool) -> void:
	show_window = value
	queue_redraw()


func set_show_camera_view(value: bool) -> void:
	show_camera_view = value
	queue_redraw()
