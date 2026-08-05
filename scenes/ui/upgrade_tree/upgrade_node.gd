@tool
extends Button
class_name UpgradeNode
## Boton del arbol de mejoras. Solo necesitas: upgrade (StatUpgrade), icono, popup y previous_skills.
## Encuentra el UpgradeTree y el contenedor de lineas solo subiendo por el arbol de nodos.

const INFO_POPUP := preload("res://scenes/ui/upgrade_tree/upgrade_info_popup.tscn")
const BUTTON_LINE := preload("res://scenes/ui/upgrade_tree/upgrade_line.tscn")
const BUTTON_BLUE = preload("uid://dw5seubmtxxkk")
const BUTTON_GREEN = preload("uid://c4cf8s0h22g8h")
const BUTTON_ORANGE = preload("uid://umgfjtije6du")
const BUTTON_RED = preload("uid://5knqqj3vnkpa")

signal skill_leveled

## Definicion de la mejora (.tres o sub-recurso inline con costs[] y values[]).
@export var upgrade: StatUpgrade

@export_category("Tree")
## Nodos que deben tener al menos 1 nivel antes de mostrar este boton.
@export var previous_skills: Array[UpgradeNode] = []

@export_category("Display")
@export var icon_tex: Texture2D:
	set(value):
		icon_tex = value
		apply_icon_texture()

@export_category("Popup")
@export var popup_title: String = ""
@export_multiline var popup_description: String = ""
@export var highlight_word: String = ""

@onready var skill_icon: TextureRect = $TextureRect

var hover_tween: Tween
var level: int = 0
var max_level: int = 0
var connection_lines: Array[UpgradeLine] = []


func _get_configuration_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()

	if upgrade == null:
		warnings.append("Asigna un StatUpgrade (id + costs + values).")
	elif upgrade.get_max_level() <= 0:
		warnings.append("El StatUpgrade no tiene niveles: rellena costs y values.")

	if popup_title.is_empty():
		warnings.append("popup_title vacio: el hover no mostrara titulo.")

	return warnings


func apply_icon_texture() -> void:
	var icon_node := get_node_or_null("TextureRect")
	if icon_node != null and icon_tex != null:
		icon_node.texture = icon_tex


func get_owner_tree() -> UpgradeTree:
	var current: Node = self
	while current != null:
		if current is UpgradeTree:
			return current as UpgradeTree
		current = current.get_parent()
	return null


func get_lines_container() -> Node2D:
	var owner_tree := get_owner_tree()
	if owner_tree != null:
		return owner_tree.lines_container
	return null


func on_prerequisite_leveled() -> void:
	# Unlock lo anima UpgradeTree en EventBus.upgrade_purchased (si mostramos aqui, no hay cascada).
	if visible:
		update_line()


## True si este nodo deberia estar disponible (todos los previous comprados al menos 1 vez).
func are_prerequisites_met() -> bool:
	if previous_skills.is_empty():
		return true
	for prev in previous_skills:
		if prev != null and prev.level <= 0:
			return false
	return true


## Desbloqueo progresivo: visible solo si are_prerequisites_met(). Devuelve true si acaba de mostrarse.
func check_prerequisites() -> bool:
	var was_visible := visible

	if are_prerequisites_met():
		show()
		disabled = false
		apply_availability_visual()
		return not was_visible

	hide()
	disabled = true
	return false


## Comprados a brillo normal; disponibles aun no comprados mas oscuros.
func apply_availability_visual() -> void:
	if not visible:
		return
	var owner_tree := get_owner_tree()
	var dim := 0.55
	if owner_tree != null:
		dim = owner_tree.unpurchased_dim
	if level > 0:
		modulate = Color(1.0, 1.0, 1.0, 1.0)
	else:
		modulate = Color(dim, dim, dim, 1.0)


func set_level(value: int) -> void:
	level = clampi(value, 0, max_level)
	apply_availability_visual()
	if level > 0:
		skill_leveled.emit()
	update_line()


## Crea las lineas de conexion si faltan (sin tocar visibilidad/color de gameplay).
func ensure_connection_lines() -> void:
	var lines_parent := get_lines_container()
	if lines_parent == null or previous_skills.is_empty():
		return
	if not connection_lines.is_empty():
		return

	for prev in previous_skills:
		if prev == null:
			continue
		var new_line: UpgradeLine = BUTTON_LINE.instantiate()
		new_line.from_button = prev
		new_line.to_button = self
		lines_parent.add_child(new_line)
		connection_lines.append(new_line)


func update_line() -> void:
	var lines_parent := get_lines_container()
	if lines_parent == null:
		return

	var owner_tree := get_owner_tree()
	if owner_tree != null and owner_tree.is_revealing:
		return

	ensure_connection_lines()
	apply_tree_line_style(owner_tree)

	var is_maxed := level >= max_level
	var has_points := level > 0
	var can_afford := false

	if not is_maxed and upgrade != null:
		var upgrade_cost := upgrade.get_cost(level)
		var player_currency: int = CurrencyManager.currency_data.currency_amount.get(
			upgrade.upgrade_material, 0
		)
		can_afford = player_currency >= upgrade_cost

	if is_maxed:
		icon = BUTTON_BLUE
	elif can_afford:
		icon = BUTTON_GREEN
	elif has_points:
		icon = BUTTON_ORANGE
	else:
		icon = BUTTON_RED

	for i in range(previous_skills.size()):
		if i >= connection_lines.size():
			break
		var prev := previous_skills[i]
		var current_line := connection_lines[i]
		if prev != null and prev.level > 0 and is_visible_in_tree() and owner_tree != null:
			current_line.visible = current_line.grow_progress >= 1.0
			current_line.apply_style(owner_tree.line_width, resolve_line_color(is_maxed, can_afford, has_points), owner_tree.line_cap_mode)
		else:
			current_line.hide()


func apply_tree_line_style(owner_tree: UpgradeTree) -> void:
	if owner_tree == null:
		return
	for line in connection_lines:
		line.apply_style(owner_tree.line_width, owner_tree.line_color_locked, owner_tree.line_cap_mode)


func resolve_line_color(is_maxed: bool, can_afford: bool, has_points: bool) -> Color:
	var owner_tree := get_owner_tree()
	if owner_tree == null:
		return Color.WHITE
	if is_maxed:
		return owner_tree.line_color_owned
	if can_afford:
		return owner_tree.line_color_affordable
	if has_points:
		return owner_tree.line_color_partial
	return owner_tree.line_color_blocked


func can_purchase() -> bool:
	if upgrade == null or level >= max_level:
		return false
	return CurrencyManager.can_afford(upgrade.upgrade_material, upgrade.get_cost(level))


func get_safe_level_index(level_index: int) -> int:
	if max_level <= 0:
		return 0
	return clampi(level_index, 0, max_level - 1)


func get_level_value(level_index: int) -> float:
	if upgrade == null:
		return 0.0
	return upgrade.get_value(get_safe_level_index(level_index))


## Sincroniza amount/cost runtime del StatUpgrade con el nivel actual (preview del popup).
func sync_runtime_from_level(level_index: int) -> void:
	if upgrade == null or max_level <= 0:
		return

	var preview_index := get_safe_level_index(level_index)
	if level_index < max_level:
		upgrade.prepare_for_level(level_index)
	else:
		upgrade.prepare_for_level(preview_index)


func format_stat_value(raw_value: float) -> String:
	if upgrade == null:
		return str(raw_value)

	var type := upgrade.display_type
	if type == StatUpgrade.OperationMode.PERCENT:
		return str(int(round(abs(raw_value) * 100.0))) + "%"
	if type == StatUpgrade.OperationMode.MULTIPLIER:
		return "x" + format_number(raw_value)
	return format_number(raw_value)


func format_number(value: float) -> String:
	if is_equal_approx(value, round(value)):
		return str(int(value))
	return str(value)


func get_popup_description(level_index: int) -> String:
	var safe_index := get_safe_level_index(level_index)
	var description_text := popup_description
	var amount_str := format_stat_value(get_level_value(safe_index))
	description_text = description_text.replace("{stat_amount}", amount_str)
	if highlight_word != "":
		description_text = description_text.replace("{highlight_word}", highlight_word)
	return description_text


func update_skill_info() -> void:
	var owner_tree := get_owner_tree()
	if owner_tree == null or upgrade == null:
		return

	if owner_tree.skill_info == null:
		owner_tree.skill_info = INFO_POPUP.instantiate()
		var lines_parent := get_lines_container()
		if lines_parent != null:
			lines_parent.add_child(owner_tree.skill_info)

	var accumulated := 0.0
	for i in range(level):
		accumulated += get_level_value(i)

	var first_stat := get_level_value(0)
	var has_stats := first_stat != 0.0
	var stat_1 := format_stat_value(accumulated)
	var stat_2 := ""
	var upgrade_cost := ""

	if level < max_level:
		var next_value := accumulated + get_level_value(level)
		upgrade_cost = str(upgrade.get_cost(level))
		stat_2 = format_stat_value(next_value)
	else:
		upgrade_cost = "MAXED"
		stat_2 = "MAXED"

	var skill_description := get_popup_description(level)
	var player_currency := str(
		CurrencyManager.currency_data.currency_amount.get(upgrade.upgrade_material, 0)
	)
	var global_canvas_pos := get_global_transform_with_canvas().origin

	owner_tree.skill_info.setup_skill_text(
		popup_title,
		skill_description,
		has_stats,
		stat_1,
		stat_2,
		player_currency,
		upgrade_cost,
		str(level),
		str(max_level),
		highlight_word
	)
	owner_tree.skill_info.show_panel(global_canvas_pos, size, owner_tree)
	owner_tree.skill_info.show()


func animate_hover() -> void:
	if hover_tween != null:
		hover_tween.kill()

	hover_tween = create_tween()
	hover_tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	hover_tween.tween_property(self, "rotation_degrees", 15.0, 0.1)
	hover_tween.chain()
	hover_tween.tween_property(self, "rotation_degrees", 0.0, 0.6).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)


func animate_click_impact() -> void:
	if hover_tween != null:
		hover_tween.kill()

	pivot_offset = size / 2.0
	rotation_degrees = 0.0

	var click_tween := create_tween()
	click_tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	click_tween.tween_property(self, "scale", Vector2(1.5, 0.5), 0.1)
	click_tween.chain().parallel().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	click_tween.tween_property(self, "scale", Vector2(0.5, 1.5), 0.1)
	click_tween.chain().parallel().set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	click_tween.tween_property(self, "scale", Vector2.ONE, 0.4)
	click_tween.chain()


func add_upgrade_to_list() -> void:
	UpgradeManager.add_upgrade(upgrade.upgrade_type, upgrade)


func _on_pressed() -> void:
	if level >= max_level or not can_purchase():
		return

	var upgrade_cost := upgrade.get_cost(level)
	animate_click_impact()

	upgrade.prepare_for_level(level)
	add_upgrade_to_list()

	level += 1
	set_level(level)
	GameManager.skill_levels[upgrade.id] = level
	CurrencyManager.remove_currency(upgrade.upgrade_material, upgrade_cost)
	GameManager.refresh_player_stats()
	EventBus.upgrade_purchased.emit()

	sync_runtime_from_level(level)
	update_skill_info()


func _on_mouse_entered() -> void:
	animate_hover()
	update_skill_info()


func _on_mouse_exited() -> void:
	var owner_tree := get_owner_tree()
	if owner_tree != null and owner_tree.skill_info != null:
		owner_tree.skill_info.hide_panel()
