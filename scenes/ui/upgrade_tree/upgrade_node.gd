@tool
extends Button
class_name UpgradeNode

const INFO_POPUP := preload("res://scenes/ui/upgrade_tree/upgrade_info_popup.tscn")
const BUTTON_LINE := preload("res://scenes/ui/upgrade_tree/upgrade_line.tscn")
const BUTTON_BLUE = preload("uid://dw5seubmtxxkk")
const BUTTON_GREEN = preload("uid://c4cf8s0h22g8h")
const BUTTON_ORANGE = preload("uid://umgfjtije6du")
const BUTTON_RED = preload("uid://5knqqj3vnkpa")

signal skill_leveled

@export var tree: UpgradeTree
@export var lines: Node2D
@export var previous_skills: Array[UpgradeNode] = []
@export var upgrade: StatUpgrade
@export var icon_tex: Texture2D:
	set(value):
		icon_tex = value
		_update_button_icon()

@export_group("Popup Setup")
@export var popup_title: String
@export_multiline var popup_description: String
@export var highlight_word: String

@onready var skill_icon: TextureRect = $TextureRect
@onready var white_rect: ColorRect = $WhiteRect

var hover_tween: Tween
var level: int = 0
var max_level: int = 0
var connection_lines: Array[UpgradeLine] = []


func _update_button_icon() -> void:
	var icon_node := get_node_or_null("TextureRect")
	if icon_node != null and icon_tex != null:
		icon_node.texture = icon_tex


func on_prerequisite_leveled() -> void:
	check_prerequisites()
	update_line()


func check_prerequisites() -> void:
	if previous_skills.is_empty():
		show()
		disabled = false
		return

	var all_unlocked := true
	for prev in previous_skills:
		if prev != null and prev.level <= 0:
			all_unlocked = false
			break

	if all_unlocked:
		show()
		disabled = false
	else:
		hide()
		disabled = true


func set_level(value: int) -> void:
	level = clampi(value, 0, max_level)
	if level > 0:
		skill_leveled.emit()
	update_line()


func update_line() -> void:
	if connection_lines.is_empty() and not previous_skills.is_empty():
		for prev in previous_skills:
			if prev == null:
				continue
			var new_line: UpgradeLine = BUTTON_LINE.instantiate()
			new_line.from_button = prev
			new_line.to_button = self
			lines.add_child(new_line)
			connection_lines.append(new_line)

	var is_maxed := level == max_level
	var has_points := level > 0
	var can_afford := false

	if not is_maxed and upgrade != null:
		var upgrade_cost := upgrade.upgrade_stats[level].cost
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
		if prev != null and prev.level > 0 and is_visible_in_tree():
			current_line.show()
			if is_maxed:
				current_line.default_color = Color("#2ebecb")
			elif can_afford:
				current_line.default_color = Color("#1a9745")
			elif has_points:
				current_line.default_color = Color("b67500ff")
			else:
				current_line.default_color = Color("#bd273e")
		else:
			current_line.hide()


func can_purchase() -> bool:
	if upgrade == null or level >= max_level:
		return false
	var upgrade_cost := upgrade.upgrade_stats[level].cost
	return CurrencyManager.can_afford(upgrade.upgrade_material, upgrade_cost)


func get_safe_index(level_index: int) -> int:
	return clampi(level_index, 0, max_level - 1)


func _get_stat_from_data(level_data: StatUpgrade, index: int) -> float:
	if level_data == null or level_data.upgrade_stats.is_empty():
		return 0.0
	if index < level_data.upgrade_stats.size():
		return float(level_data.upgrade_stats[index].stat_amount)
	return 0.0


func _set_upgrade_stats(level_index: int) -> void:
	if upgrade.upgrade_stats.is_empty():
		push_warning("No Upgrade Stats for %s" % upgrade.skill_id)
		return

	var safe_index := clampi(level_index, 0, max_level - 1)
	upgrade.amount = _get_stat_from_data(upgrade, safe_index)

	if level_index < upgrade.upgrade_stats.size():
		upgrade.cost = upgrade.upgrade_stats[level_index].cost
	else:
		upgrade.cost = upgrade.upgrade_stats[safe_index].cost


func _format_stat_value(raw_value: float) -> String:
	var type := upgrade.display_type
	if type == StatUpgrade.OperationMode.PERCENT:
		return str(int(round(abs(raw_value) * 100.0))) + "%"
	if type == StatUpgrade.OperationMode.MULTIPLIER:
		return "x" + _format_number(raw_value)
	return _format_number(raw_value)


func _format_number(value: float) -> String:
	if is_equal_approx(value, round(value)):
		return str(int(value))
	return str(value)


func _get_popup_description(level_index: int) -> String:
	var safe_index := get_safe_index(level_index)
	var description_text := popup_description
	var raw_amount: float = _get_stat_from_data(upgrade, safe_index)
	var amount_str := _format_stat_value(raw_amount)
	description_text = description_text.replace("{stat_amount}", amount_str)
	if highlight_word != "":
		description_text = description_text.replace("{highlight_word}", highlight_word)
	return description_text


func _update_skill_info() -> void:
	if tree != null and tree.skill_info == null:
		tree.skill_info = INFO_POPUP.instantiate()
		lines.add_child(tree.skill_info)

	var accumulated := 0.0
	for i in range(level):
		if i < max_level:
			accumulated += _get_stat_from_data(upgrade, i)

	var first_stat := _get_stat_from_data(upgrade, 0)
	var has_stats := first_stat != 0.0
	var stat_1 := _format_stat_value(accumulated)
	var stat_2 := ""
	var upgrade_cost := ""

	if level < max_level:
		var next_value := accumulated + _get_stat_from_data(upgrade, level)
		upgrade_cost = str(int(upgrade.cost))
		stat_2 = _format_stat_value(next_value)
	else:
		upgrade_cost = "MAXED"
		stat_2 = "MAXED"

	var skill_description := _get_popup_description(level)
	var player_currency := str(
		CurrencyManager.currency_data.currency_amount.get(upgrade.upgrade_material, 0)
	)
	var global_canvas_pos := get_global_transform_with_canvas().origin

	tree.skill_info.setup_skill_text(
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
	tree.skill_info.show_panel(global_canvas_pos, size, tree)
	tree.skill_info.show()


func _animate_hover() -> void:
	if hover_tween != null:
		hover_tween.kill()

	hover_tween = create_tween()
	hover_tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	hover_tween.tween_property(self, "rotation_degrees", 15.0, 0.1)
	hover_tween.chain()
	hover_tween.tween_property(self, "rotation_degrees", 0.0, 0.6).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)


func _animate_click_impact() -> void:
	if hover_tween != null:
		hover_tween.kill()

	pivot_offset = size / 2.0
	rotation_degrees = 0.0
	white_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	white_rect.visible = true
	white_rect.modulate.a = 1.0

	var click_tween := create_tween()
	click_tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	click_tween.tween_property(self, "scale", Vector2(1.5, 0.5), 0.1)
	click_tween.chain().parallel().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	click_tween.tween_property(self, "scale", Vector2(0.5, 1.5), 0.1)
	click_tween.tween_property(white_rect, "modulate:a", 0.0, 0.1)
	click_tween.chain().parallel().set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	click_tween.tween_property(self, "scale", Vector2.ONE, 0.4)
	click_tween.chain()
	click_tween.tween_callback(func(): white_rect.visible = false)


func _add_upgrade_to_list() -> void:
	UpgradeManager.add_upgrade(upgrade.upgrade_type, upgrade)


func _on_pressed() -> void:
	if level >= max_level or not can_purchase():
		return

	var upgrade_cost := upgrade.upgrade_stats[level].cost
	_animate_click_impact()

	upgrade.amount = _get_stat_from_data(upgrade, level)
	upgrade.cost = upgrade.upgrade_stats[level].cost
	_add_upgrade_to_list()

	level += 1
	set_level(level)
	GameManager.skill_levels[upgrade.skill_id] = level
	CurrencyManager.remove_currency(upgrade.upgrade_material, upgrade_cost)
	GameManager.refresh_player_stats()
	EventBus.upgrade_purchased.emit()

	_set_upgrade_stats(level)
	_update_skill_info()


func _on_mouse_entered() -> void:
	_animate_hover()
	_update_skill_info()


func _on_mouse_exited() -> void:
	if tree != null and tree.skill_info != null:
		tree.skill_info.hide_panel()
