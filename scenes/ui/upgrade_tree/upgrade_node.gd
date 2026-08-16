extends Node2D
class_name UpgradeNode

signal first_purchase
signal maxed_purchase
signal purchased(node)

static var show_all := false

const GRID_STEP := 75.0
const GREEN_COLOR = Color("00e641")
const YELLOW_COLOR = Color("ffdd00")
const RED_COLOR = Color("ff4242")

@export var upgrade: StatUpgrade
@export var upgrade_key: String = ""
@export var popup_title: String = ""
@export var popup_description: String = ""
@export_category("Progress")
@export var current_level: int = 0
@export var maximum_level: int = 10
@export var cost_ore: int = Ores.GOLD
@export var upgrade_price: UpgradePrice
@export var upgrade_values: Array[float]
@export_category("Connections")
@export var node_connections: Array[UpgradeNode] = []

@onready var icon: Sprite2D = %Icon
@onready var button: Button = $Button
@onready var visuals: Panel = $Visuals
@onready var tier_label: Label = %TierLabel
@onready var hover_sfx: AudioStreamPlayer = $Hover
@onready var click_sfx: AudioStreamPlayer = $Click
@onready var item_popup: ItemPopup = $ItemPopup

var unlocked := false

func _ready():
	visuals.pivot_offset = visuals.size * 0.5
	button.pivot_offset = button.size * 0.5
	if Engine.is_editor_hint():
		return
	if upgrade != null:
		maximum_level = upgrade.get_max_level()
		current_level = UpgradeManager.get_level(upgrade.id)


## Gamepad: vecinos a 75px; no se cablean en el inspector.
func setup_neighbors() -> void:
	button.set_focus_neighbor(SIDE_LEFT, NodePath(""))
	button.set_focus_neighbor(SIDE_TOP, NodePath(""))
	button.set_focus_neighbor(SIDE_RIGHT, NodePath(""))
	button.set_focus_neighbor(SIDE_BOTTOM, NodePath(""))
	if not visible:
		return
	for child in get_parent().get_children():
		var neighbor := child as UpgradeNode
		if neighbor == null or neighbor == self or not neighbor.visible:
			continue
		var diff: Vector2 = neighbor.position - position
		if diff.is_equal_approx(GRID_STEP * Vector2.LEFT):
			button.set_focus_neighbor(SIDE_LEFT, button.get_path_to(neighbor.button))
		elif diff.is_equal_approx(GRID_STEP * Vector2.UP):
			button.set_focus_neighbor(SIDE_TOP, button.get_path_to(neighbor.button))
		elif diff.is_equal_approx(GRID_STEP * Vector2.RIGHT):
			button.set_focus_neighbor(SIDE_RIGHT, button.get_path_to(neighbor.button))
		elif diff.is_equal_approx(GRID_STEP * Vector2.DOWN):
			button.set_focus_neighbor(SIDE_BOTTOM, button.get_path_to(neighbor.button))


## Conexiones salientes validas (ignora huecos vacios del inspector).
func get_connected_nodes() -> Array:
	var result: Array = []
	for item in node_connections:
		if item is UpgradeNode:
			result.append(item)
	return result


## Visibilidad por desbloqueo y borde verde/rojo/amarillo. El popup lo llena UpgradeTree.
func update_status() -> void:
	if Engine.is_editor_hint():
		visible = true
		return

	var was_visible := visible
	visible = unlocked or show_all
	if visible and not was_visible:
		Springer.scale(visuals, -1.0, 1.0)

	tier_label.visible = false
	visuals.modulate = Color("404040") if current_level == 0 else Color.WHITE
	icon.modulate = Color("c0c0c0") if current_level == 0 else Color("808080")

	if current_level == maximum_level:
		button.disabled = true
		set_button_border(YELLOW_COLOR)
	elif can_afford() and unlocked:
		button.disabled = false
		set_button_border(GREEN_COLOR)
	else:
		button.disabled = true
		set_button_border(RED_COLOR)


func get_popup_progress() -> String:
	return ""


func get_popup_price() -> String:
	if current_level < maximum_level:
		var owned = CurrencyManager.get_ore_amount(Ores.get_id(get_cost_ore()))
		return "%d/%d" % [owned, get_current_price()]
	return "[color=ffe524]MAXED[/color]"


func format_variable(value: float) -> String:
	if upgrade != null and upgrade.display_type == StatUpgrade.OperationMode.PERCENT:
		return str(int(round(abs(value) * 100.0))) + "%"
	if upgrade != null and upgrade.display_type == StatUpgrade.OperationMode.MULTIPLIER:
		return "x%.1f" % value
	if is_equal_approx(value, roundf(value)):
		return "%d" % roundi(value)
	return "%.1f" % value


func get_current_upgrade():
	if upgrade != null:
		var accumulated := 0.0
		for i in range(current_level):
			accumulated += upgrade.get_value(i)
		return accumulated
	return 0.0


func get_cost_ore() -> int:
	if upgrade != null:
		return upgrade.cost_ore
	return cost_ore


func can_afford() -> bool:
	return CurrencyManager.can_afford_ore_type(get_cost_ore(), get_current_price())


func get_current_price():
	if upgrade != null:
		return upgrade.get_cost(current_level)
	if upgrade_price != null:
		return upgrade_price.calculate(current_level)
	return 0


## Borde del panel visible. El Button solo existe para focus/gamepad.
func set_button_border(color: Color) -> void:
	var box := visuals.get_theme_stylebox("panel")
	if box is StyleBoxFlat:
		(box as StyleBoxFlat).border_color = color


func _on_visuals_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_on_button_pressed()


func _on_button_pressed():
	click_sfx.play()
	Springer.rotate(visuals, 12.0 * [-1.0, 1.0].pick_random())
	Springer.scale(visuals, 0.1, 1.0)
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
		Refs.shake_camera(10.0)
		if previous_level == 0:
			first_purchase.emit()
		if current_level == maximum_level:
			maxed_purchase.emit()


func _on_button_mouse_entered():
	SFX.play(Sound.BUTTON_HOVER)
	Springer.rotate(visuals, 18)
	item_popup.set_content(popup_title, popup_description, get_popup_progress(), get_popup_price())
	item_popup.appear()


func _on_button_mouse_exited():
	item_popup.disappear()
