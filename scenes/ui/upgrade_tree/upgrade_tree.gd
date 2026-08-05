extends Control
class_name UpgradeTree
## Panel del arbol de mejoras. Reveal estilo ShellDiver: cascada BFS (linea crece -> nodo pop).

@export var content: Control
@export var lines_container: Node2D

@export_category("Connection Lines")
@export var line_width: float = 6.0
@export var line_cap_mode: Line2D.LineCapMode = Line2D.LINE_CAP_ROUND
@export var line_color_locked: Color = Color("#343434")
@export var line_color_owned: Color = Color("#2ebecb")
@export var line_color_affordable: Color = Color("#1a9745")
@export var line_color_partial: Color = Color("b67500ff")
@export var line_color_blocked: Color = Color("#bd273e")

@export_category("Reveal Animation")
@export var play_reveal_on_open: bool = true
@export_group("Timing")
## Duracion del pop del nodo (scale + rotacion).
@export var node_reveal_duration: float = 0.22
## Duracion de la linea creciendo hacia el hijo (ShellDiver: muy rapida).
@export var line_grow_duration: float = 0.14
## Delay entre hermanos al disparar lineas en la misma ola.
@export var sibling_stagger: float = 0.045
## Delay entre roots si hay varios.
@export var root_stagger: float = 0.04
## Pausa minima despues del pop antes de disparar lineas salientes.
@export var post_node_delay: float = 0.02
@export_group("Node Pop")
## Rotacion inicial del nodo al aparecer (se asienta a 0).
@export var node_start_rotation_deg: float = -14.0
## Fuerza del temblor Springer al TERMINAR la secuencia (0 = sin temblor).
@export var node_reveal_spring: float = 0.14
## Flash de brillo al pop (1 = sin flash).
@export var node_flash_peak: float = 1.45
@export var node_flash_duration: float = 0.12
@export_group("Line Grow")
@export var line_grow_trans: Tween.TransitionType = Tween.TRANS_QUART
@export var line_grow_ease: Tween.EaseType = Tween.EASE_OUT
@export_group("Availability")
## Multiplicador de modulate para nodos visibles pero aun no comprados.
@export var unpurchased_dim: float = 0.55
@export var juice_preset: JuicePreset

@onready var buttons: Control = %Buttons
@onready var maxed_message: PanelContainer = $MaxedMessage

var dragging: bool = false
var zoom: float = 1.0
var min_zoom: float = 0.25
var max_zoom: float = 1.0
var zoom_step: float = 0.1
var skill_info: UpgradeInfoPopup = null
var is_revealing: bool = false
var node_rest_positions: Dictionary = {}
var reveal_jobs_remaining: int = 0


func _ready() -> void:
	visible = false
	content.pivot_offset = Vector2.ZERO
	$TreeViewport.clip_contents = true

	if EventBus.upgrade_purchased.is_connected(_update_lines):
		EventBus.upgrade_purchased.disconnect(_update_lines)
	EventBus.upgrade_purchased.connect(_update_lines)

	if EventBus.currency_ui_update.is_connected(_update_currency_label):
		EventBus.currency_ui_update.disconnect(_update_currency_label)
	EventBus.currency_ui_update.connect(_update_currency_label)

	_initialize_view.call_deferred()
	setup_buttons.call_deferred()
	_update_currency_label.call_deferred()


func show_panel() -> void:
	show()
	reset_nodes_visual_state(collect_upgrade_nodes())
	setup_buttons()
	_update_currency_label()
	if play_reveal_on_open:
		play_reveal_sequence.call_deferred()
	else:
		finish_reveal_state(collect_upgrade_nodes())


func reset_nodes_visual_state(nodes: Array[UpgradeNode]) -> void:
	is_revealing = false
	reveal_jobs_remaining = 0
	for node in nodes:
		node.scale = Vector2.ONE
		node.rotation_degrees = 0.0
		node.self_modulate = Color.WHITE
		node.modulate.a = 1.0 if node.is_visible() else 0.0
		node.disabled = false
		for line in node.connection_lines:
			line.grow_progress = 1.0
			line.clear_endpoint_lock()


func finish_reveal_state(nodes: Array[UpgradeNode]) -> void:
	for node in nodes:
		# Restaurar transform aunque este oculto: si no, al desbloquear queda invisible (a=0).
		node.scale = Vector2.ONE
		node.rotation_degrees = 0.0
		node.self_modulate = Color.WHITE
		node.check_prerequisites()
		node.apply_availability_visual()
		for line in node.connection_lines:
			line.clear_endpoint_lock()
		node.update_line()

	is_revealing = false
	reveal_jobs_remaining = 0

	for node in nodes:
		if node.is_visible():
			UpgradeTreeJuice.apply_finish_spring(node, node_reveal_spring)


func close() -> void:
	if skill_info != null:
		skill_info.hide_panel()
	visible = false
	is_revealing = false
	reveal_jobs_remaining = 0


func setup_buttons() -> void:
	var upgrade_nodes := collect_upgrade_nodes()

	for node in upgrade_nodes:
		if node.upgrade == null:
			continue

		node.max_level = node.upgrade.get_max_level()
		node.level = GameManager.skill_levels.get(node.upgrade.id, 0)
		if node.icon_tex != null:
			node.skill_icon.texture = node.icon_tex
		node.sync_runtime_from_level(node.level)
		node.apply_tree_line_style(self)

	for node in upgrade_nodes:
		node.check_prerequisites()
		node.apply_availability_visual()
		node.update_line()

		if not node.item_rect_changed.is_connected(node.update_line):
			node.item_rect_changed.connect(node.update_line)

		for prev in node.previous_skills:
			if prev == null:
				continue
			if not prev.item_rect_changed.is_connected(node.update_line):
				prev.item_rect_changed.connect(node.update_line)
			if not prev.skill_leveled.is_connected(node.on_prerequisite_leveled):
				prev.skill_leveled.connect(node.on_prerequisite_leveled)


func collect_upgrade_nodes() -> Array[UpgradeNode]:
	var upgrade_nodes: Array[UpgradeNode] = []
	for child in buttons.get_children():
		if child is UpgradeNode:
			upgrade_nodes.append(child)
	return upgrade_nodes


## Cascada ShellDiver: roots pop -> lineas crecen en olas BFS -> hijo pop al llegar la linea.
func play_reveal_sequence() -> void:
	if is_revealing:
		return
	is_revealing = true

	var nodes := collect_upgrade_nodes()
	cache_node_rest_positions(nodes)
	ensure_reveal_lines(nodes)
	prepare_nodes_for_reveal(nodes)

	var roots := get_root_nodes(nodes)
	if roots.is_empty():
		finish_reveal_state(nodes)
		return

	var revealed: Dictionary = {}
	for i in range(roots.size()):
		var root := roots[i]
		if i > 0 and root_stagger > 0.0:
			await get_tree().create_timer(root_stagger).timeout
		await pop_reveal_node(root)
		revealed[root] = true

	var wave: Array[UpgradeNode] = roots.duplicate()
	while not wave.is_empty():
		if post_node_delay > 0.0:
			await get_tree().create_timer(post_node_delay).timeout

		var edge_jobs: Array[Dictionary] = []
		var delay := 0.0
		for parent in wave:
			for child in get_dependent_nodes(parent, nodes):
				if revealed.has(child) or not child.is_visible():
					continue
				if not are_previous_revealed(child, revealed):
					continue
				var line := find_connection_line(child, parent)
				if line == null:
					continue
				edge_jobs.append({
					"parent": parent,
					"child": child,
					"line": line,
					"delay": delay,
				})
				revealed[child] = true
				delay += sibling_stagger

		if edge_jobs.is_empty():
			break

		reveal_jobs_remaining = edge_jobs.size()
		for job in edge_jobs:
			run_edge_reveal_job(job)

		while reveal_jobs_remaining > 0:
			await get_tree().process_frame

		var next_wave: Array[UpgradeNode] = []
		for job in edge_jobs:
			next_wave.append(job["child"])
		wave = next_wave

	for node in nodes:
		if node.is_visible() and not revealed.has(node):
			await pop_reveal_node(node)
			for line in node.connection_lines:
				line.grow_progress = 1.0
				line.visible = true

	finish_reveal_state(nodes)


func run_edge_reveal_job(job: Dictionary) -> void:
	var delay: float = job["delay"]
	var line: UpgradeLine = job["line"]
	var child: UpgradeNode = job["child"]
	var parent: UpgradeNode = job["parent"]

	if delay > 0.0:
		await get_tree().create_timer(delay).timeout

	line.apply_style(line_width, resolve_line_color(child), line_cap_mode)
	lock_line_to_rest_centers(line, parent, child)
	await UpgradeTreeJuice.animate_line_grow(self, line, line_grow_duration, line_grow_trans, line_grow_ease).finished
	await pop_reveal_node(child)
	reveal_jobs_remaining = maxi(reveal_jobs_remaining - 1, 0)


func lock_line_to_rest_centers(line: UpgradeLine, from_node: UpgradeNode, to_node: UpgradeNode) -> void:
	var from_rest: Vector2 = node_rest_positions.get(from_node, from_node.position)
	var to_rest: Vector2 = node_rest_positions.get(to_node, to_node.position)
	var from_global := get_node_rest_global_center(from_node, from_rest)
	var to_global := get_node_rest_global_center(to_node, to_rest)
	line.lock_to_rest_centers(from_global, to_global)


func get_node_rest_global_center(node: UpgradeNode, rest_position: Vector2) -> Vector2:
	# Control no tiene to_global; CanvasItem usa get_global_transform().
	var local_center := rest_position + node.size * 0.5
	var parent_node := node.get_parent() as CanvasItem
	if parent_node == null:
		return node.get_global_transform() * (node.size * 0.5)
	return parent_node.get_global_transform() * local_center


func pop_reveal_node(node: UpgradeNode) -> void:
	var rest_pos: Vector2 = node_rest_positions.get(node, node.position)
	await UpgradeTreeJuice.reveal_node(
		self,
		node,
		rest_pos,
		node_reveal_duration,
		node_start_rotation_deg,
		node_flash_peak,
		node_flash_duration
	).finished
	node.check_prerequisites()


func cache_node_rest_positions(nodes: Array[UpgradeNode]) -> void:
	node_rest_positions.clear()
	for node in nodes:
		node_rest_positions[node] = node.position


func prepare_nodes_for_reveal(nodes: Array[UpgradeNode]) -> void:
	for node in nodes:
		kill_node_spring(node)
		for line in node.connection_lines:
			line.reset_grow()
		if node.is_visible():
			UpgradeTreeJuice.prepare_node_hidden(node, node_rest_positions.get(node, node.position), node_start_rotation_deg)
		else:
			node.modulate.a = 0.0


func kill_node_spring(node: UpgradeNode) -> void:
	if not Springer.scale_springs.has(node):
		return
	var spr: Spring = Springer.scale_springs[node]
	spr.is_killed = true
	Springer.scale_springs.erase(node)


func ensure_reveal_lines(nodes: Array[UpgradeNode]) -> void:
	for node in nodes:
		node.ensure_connection_lines()
		node.apply_tree_line_style(self)


func get_root_nodes(nodes: Array[UpgradeNode]) -> Array[UpgradeNode]:
	var roots: Array[UpgradeNode] = []
	for node in nodes:
		if node.previous_skills.is_empty() and node.is_visible():
			roots.append(node)
	if roots.is_empty():
		for node in nodes:
			if node.is_visible():
				roots.append(node)
	return roots


func get_dependent_nodes(source: UpgradeNode, nodes: Array[UpgradeNode]) -> Array[UpgradeNode]:
	var dependents: Array[UpgradeNode] = []
	for node in nodes:
		if source in node.previous_skills:
			dependents.append(node)
	return dependents


func find_connection_line(child: UpgradeNode, parent: UpgradeNode) -> UpgradeLine:
	for i in range(child.previous_skills.size()):
		if child.previous_skills[i] != parent:
			continue
		if i >= child.connection_lines.size():
			return null
		return child.connection_lines[i]
	return null


func are_previous_revealed(node: UpgradeNode, revealed: Dictionary) -> bool:
	if node.previous_skills.is_empty():
		return true
	for prev in node.previous_skills:
		if prev == null:
			continue
		if prev.is_visible() and not revealed.has(prev):
			return false
	return true


func resolve_line_color(node: UpgradeNode) -> Color:
	if node.level >= node.max_level:
		return line_color_owned
	if node.can_purchase():
		return line_color_affordable
	if node.level > 0:
		return line_color_partial
	return line_color_blocked


func change_zoom(delta: float, mouse_pos: Vector2) -> void:
	var old_zoom := zoom
	zoom = clampf(zoom + delta, min_zoom, max_zoom)
	if is_equal_approx(old_zoom, zoom):
		return

	var mouse_to_topleft := mouse_pos - content.global_position
	var zoom_factor := zoom / old_zoom
	var shift := mouse_to_topleft * (zoom_factor - 1.0)

	content.position -= shift
	content.scale = Vector2.ONE * zoom


func _initialize_view() -> void:
	content.scale = Vector2.ONE * zoom
	var window_size = $TreeViewport.size
	var content_size := content.size * zoom
	content.position = (window_size / 2.0) - (content_size / 2.0)


func _update_lines() -> void:
	if is_revealing:
		return

	var newly_unlocked := collect_newly_available_nodes()
	var all_maxed := true

	for node in collect_upgrade_nodes():
		if node in newly_unlocked:
			continue
		node.check_prerequisites()
		node.update_line()
		if node.level < node.max_level:
			all_maxed = false

	if all_maxed and buttons.get_child_count() > 0:
		maxed_message.show()
	else:
		maxed_message.hide()

	if not newly_unlocked.is_empty() and visible:
		play_unlock_cascade(newly_unlocked)


## Nodos ocultos cuyos previous ya estan comprados (listos para revelarse).
func collect_newly_available_nodes() -> Array[UpgradeNode]:
	var newly_unlocked: Array[UpgradeNode] = []
	for node in collect_upgrade_nodes():
		if node.visible:
			node.apply_availability_visual()
			continue
		if node.are_prerequisites_met():
			newly_unlocked.append(node)
	return newly_unlocked


## Mini cascada al comprar: linea crece hacia el hijo recien disponible y hace pop oscuro.
func play_unlock_cascade(newly_unlocked: Array[UpgradeNode]) -> void:
	if is_revealing or newly_unlocked.is_empty():
		return
	is_revealing = true

	for node in newly_unlocked:
		if not node_rest_positions.has(node):
			node_rest_positions[node] = node.position
		node.ensure_connection_lines()
		for line in node.connection_lines:
			line.reset_grow()
		UpgradeTreeJuice.prepare_node_hidden(node, node_rest_positions.get(node, node.position), node_start_rotation_deg)
		node.show()
		node.disabled = false

		for i in range(node.previous_skills.size()):
			var prev := node.previous_skills[i]
			if prev == null or prev.level <= 0 or i >= node.connection_lines.size():
				continue
			var line: UpgradeLine = node.connection_lines[i]
			line.apply_style(line_width, resolve_line_color(node), line_cap_mode)
			lock_line_to_rest_centers(line, prev, node)
			await UpgradeTreeJuice.animate_line_grow(self, line, line_grow_duration, line_grow_trans, line_grow_ease).finished

		await pop_reveal_node(node)
		node.apply_availability_visual()
		for line in node.connection_lines:
			line.clear_endpoint_lock()
			line.grow_progress = 1.0
			line.visible = prev_purchased_for_line(node, line)

	is_revealing = false
	for node in newly_unlocked:
		node.update_line()
		if node.visible:
			UpgradeTreeJuice.apply_finish_spring(node, node_reveal_spring)


func prev_purchased_for_line(node: UpgradeNode, line: UpgradeLine) -> bool:
	for i in range(node.connection_lines.size()):
		if node.connection_lines[i] != line:
			continue
		if i >= node.previous_skills.size():
			return false
		var prev := node.previous_skills[i]
		return prev != null and prev.level > 0
	return false


func _update_currency_label() -> void:
	var money: int = CurrencyManager.currency_data.currency_amount.get(CurrencyData.CurrencyType.MONEY, 0)


func _input(event: InputEvent) -> void:
	if not visible or is_revealing:
		return

	if event is InputEventMouseButton and event.is_pressed():
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			change_zoom(zoom_step, event.position)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			change_zoom(-zoom_step, event.position)

	if event.is_action("right_click"):
		dragging = event.is_pressed()
	elif event is InputEventMouseMotion and dragging:
		content.position += event.relative
		if skill_info != null:
			skill_info.hide_panel()


func _on_close_button_pressed() -> void:
	var parent_gui := get_parent()
	if parent_gui is GUI:
		parent_gui.close_upgrade_tree()
	else:
		close()
		GameManager.curr_state = GameManager.GameStates.PLAYING
