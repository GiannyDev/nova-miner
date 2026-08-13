@tool
extends Node2D
class_name UpgradeNode

signal first_purchase
signal maxed_purchase
signal purchased(node)

static var show_all := false

const UNKNOWN_ICON = 99

const GREEN_COLOR = Color("00e641")
const YELLOW_COLOR = Color("ffdd00")
const RED_COLOR = Color("ff4242")

enum VariableType { 
	Integer, 
	Float, 
	Percentage, 
	Money 
}

@export var upgrade: StatUpgrade
@export_multiline var upgrade_key: String = ""
@export var popup_title: String = ""
@export_multiline var popup_description: String = ""
@export var disabled: bool = false
@export var upgrade_variable: String = ""
@export var rate_variable: String = ""
@export var tier: int = 0
@export var variable_type := VariableType.Integer
@export var icon_index: int = 0
@export var current_level: int = 0
@export var maximum_level: int = 10
@export var cost_ore: int = Ores.GOLD
@export var upgrade_price: UpgradePrice
@export var node1: UpgradeNode
@export var node1_max_level := false
@export var node2: UpgradeNode
@export var node2_max_level := false
@export var left_neighbor: UpgradeNode
@export var top_neighbor: UpgradeNode
@export var right_neighbor: UpgradeNode
@export var bottom_neighbor: UpgradeNode
@export var tooltip_lift := 80.0

@onready var tooltip_host: Node2D = %TooltipHost
@onready var tooltip: PanelContainer = %Tooltip
@onready var tooltip_title: Label = %Title
@onready var tooltip_description: RichTextLabel = %Description
@onready var tooltip_price: RichTextLabel = %Price
@onready var button: Button = $Button
@onready var icon: Sprite2D = %Icon
@onready var tier_label: Label = %TierLabel
@onready var hover_sfx: AudioStreamPlayer = $Button/Hover
@onready var click_sfx: AudioStreamPlayer = $Button/Click


func _ready():
	tooltip.modulate.a = 0.0
	tooltip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.pivot_offset = button.size * 0.5
	if Engine.is_editor_hint():
		return
	if upgrade != null:
		maximum_level = upgrade.get_max_level()
		current_level = UpgradeManager.get_level(upgrade.id)


func _process(_delta):
	if icon.hframes * icon.vframes <= 1:
		return
	if not Engine.is_editor_hint():
		icon.frame = UNKNOWN_ICON if is_previewed() else icon_index
	else:
		icon.frame = icon_index


## Gamepad: vecinos a 75px, cableados por RecalculateNeighbors.
func setup_neighbors():
	if left_neighbor:
		button.set_focus_neighbor(SIDE_LEFT, button.get_path_to(left_neighbor.button))
	if top_neighbor:
		button.set_focus_neighbor(SIDE_TOP, button.get_path_to(top_neighbor.button))
	if right_neighbor:
		button.set_focus_neighbor(SIDE_RIGHT, button.get_path_to(right_neighbor.button))
	if bottom_neighbor:
		button.set_focus_neighbor(SIDE_BOTTOM, button.get_path_to(bottom_neighbor.button))


## Visibilidad, colores (verde/rojo/amarillo) y texto del tooltip hijo.
func update_status():
	visible = (not disabled and (is_shown() or is_previewed())) or show_all

	tier_label.visible = tier > 0 and is_shown()
	tier_label.text = get_roman_numeral(tier)

	var title_text = popup_title if popup_title != "" else upgrade_key
	var desc_text = popup_description
	var progress_text = " (%d/%d)" % [current_level, maximum_level]
	if is_shown():
		tooltip_title.text = title_text + progress_text
	else:
		tooltip_title.text = title_text

	var current_upgrade = get_current_upgrade()
	var rate_value = get_rate_value()
	if rate_value != 0.0 or current_upgrade != 0.0:
		var future_upgrade = current_upgrade + rate_value
		var current_upgrade_text = format_variable(current_upgrade)
		var rate_value_text = format_variable(rate_value)
		var future_upgrade_text = format_variable(future_upgrade)

		current_upgrade_text = current_upgrade_text.replace("-", "")
		rate_value_text = rate_value_text.replace("-", "")
		future_upgrade_text = future_upgrade_text.replace("-", "")

		if desc_text.contains("{stat_amount}"):
			desc_text = desc_text.replace("{stat_amount}", rate_value_text)
		elif desc_text.contains("%s"):
			desc_text = desc_text % rate_value_text

		if current_level < maximum_level:
			desc_text += "\n%s > %s" % [current_upgrade_text, future_upgrade_text]
		else:
			desc_text += "\n%s" % [current_upgrade_text]

	if current_level < maximum_level:
		var owned = CurrencyManager.get_ore_amount(Ores.get_id(get_cost_ore()))
		tooltip_price.text = "%d/%d" % [owned, get_current_price()]
	else:
		tooltip_price.text = "[color=ffe524]MAXED[/color]"

	if is_shown():
		tooltip_description.text = desc_text
	elif node1 != null and node1_max_level:
		tooltip_description.text = "Requires maxed %s" % [node1.popup_title if node1.popup_title != "" else node1.upgrade_key]

	button.modulate = Color("404040") if current_level == 0 else Color.WHITE
	icon.modulate = Color("c0c0c0") if current_level == 0 else Color("808080")

	if current_level == maximum_level:
		button.disabled = true
		set_button_border(YELLOW_COLOR)
	elif can_afford() and not is_locked():
		button.disabled = false
		set_button_border(GREEN_COLOR)
	else:
		button.disabled = true
		set_button_border(RED_COLOR)
	ready_tooltip()
	ready_tooltip.call_deferred()


func format_variable(value: float) -> String:
	if variable_type == VariableType.Integer:
		return "%d" % value
	if variable_type == VariableType.Float:
		return "%.1f" % value
	if variable_type == VariableType.Percentage:
		return str(int(round(abs(value) * 100.0))) + "%"
	return str(value)


func get_current_upgrade():
	if upgrade != null:
		var accumulated := 0.0
		for i in range(current_level):
			accumulated += upgrade.get_value(i)
		return accumulated
	return 0.0


func get_rate_value():
	if upgrade != null and current_level < maximum_level:
		return upgrade.get_value(current_level)
	return 0.0


func get_cost_ore() -> int:
	if upgrade != null:
		return upgrade.cost_ore
	return cost_ore


func can_afford() -> bool:
	return CurrencyManager.can_afford_ore_type(get_cost_ore(), get_current_price())


func at_max():
	return current_level == maximum_level


func is_previewed():
	return is_locked() and ((node1 != null and node1.current_level > 0 and node1_max_level) or (node2 != null and node2.current_level > 0 and node2_max_level))


func is_shown():
	return not is_locked()


func is_locked():
	var locked = false
	locked = locked or (node1 != null and node1.current_level < (node1.maximum_level if node1_max_level else 1))
	locked = locked or (node2 != null and node2.current_level < (node2.maximum_level if node2_max_level else 1))
	return locked


func grab_focus():
	button.grab_focus()


func get_progress():
	return float(current_level) / float(maximum_level)


func get_current_price():
	if upgrade != null:
		return upgrade.get_cost(current_level)
	if upgrade_price != null:
		return upgrade_price.calculate(current_level)
	return 0


func spawn():
	Springer.scale(button, -1.0, 1.0)


## Panel stays scale 1. Host Node2D at (0, -lift) is the spring target — Control pivot is not used.
func ready_tooltip() -> void:
	tooltip.reset_size()
	var sz := tooltip.get_combined_minimum_size()
	if sz.x < 1.0:
		sz = tooltip.size
	if sz.x < 1.0:
		return
	tooltip.size = sz
	tooltip.position = -sz * 0.5
	tooltip.scale = Vector2.ONE
	tooltip.rotation = 0.0
	tooltip_host.position = Vector2(0.0, -tooltip_lift)
	tooltip_host.scale = Vector2.ONE
	tooltip_host.rotation = 0.0


## StyleBoxes are local-to-scene; tint all states so hover/press keep the same rim.
func set_button_border(color: Color) -> void:
	for kind in ["normal", "pressed", "hover", "disabled"]:
		var box := button.get_theme_stylebox(kind)
		if box is StyleBoxFlat:
			(box as StyleBoxFlat).border_color = color


func get_roman_numeral(n: int) -> String:
	const NUMERALS = ["", "I", "II", "III", "IV", "V", "VI", "VII", "VIII", "IX", "X"]
	if n >= 0 and n < NUMERALS.size():
		return NUMERALS[n]
	return str(n)


func _on_button_pressed():
	click_sfx.play()
	Springer.rotate(button, 12.0 * [-1.0, 1.0].pick_random())
	Springer.scale(button, 0.1, 1.0)
	if upgrade != null:
		if not UpgradeManager.purchase(upgrade):
			return
		var previous_level = current_level
		current_level = UpgradeManager.get_level(upgrade.id)
		purchased.emit(self)
		if previous_level == 0:
			first_purchase.emit()
		if current_level == maximum_level:
			maxed_purchase.emit()
		return

	var current_price = get_current_price()
	if CurrencyManager.can_afford_ore_type(get_cost_ore(), current_price):
		CurrencyManager.spend_ore_type(get_cost_ore(), current_price)
		var previous_level = current_level
		current_level = clamp(current_level + 1, 0, maximum_level)
		purchased.emit(self)
		if previous_level == 0:
			first_purchase.emit()
		if current_level == maximum_level:
			maxed_purchase.emit()


func _on_button_mouse_entered():
	hover_sfx.play()
	ready_tooltip()
	tooltip.modulate.a = 1.0
	Springer.rotate(tooltip_host, 5)
	Springer.scale(tooltip_host, 0.5)


func _on_button_mouse_exited():
	Springer.kill_on(tooltip_host)
	tooltip_host.scale = Vector2.ONE
	tooltip_host.rotation = 0.0
	tooltip.modulate.a = 0.0
