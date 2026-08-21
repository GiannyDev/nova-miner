@tool
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

@export_category("Identity")
@export var upgrade_id: String = ""
@export var upgrade_type: Upgrades.Type = Upgrades.Type.ATTACK

@export_category("Levels")
@export var cost_ore: int = Ores.GOLD
@export var costs: Array[int] = []
@export var values: Array[float] = []

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
var current_level := 0
var maximum_level := 0


func _ready():
	visuals.pivot_offset = visuals.size * 0.5
	button.pivot_offset = button.size * 0.5
	if Engine.is_editor_hint():
		return
	sync_from_save()


func _get_configuration_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()
	if upgrade_id.is_empty():
		warnings.append("Asigna upgrade_id unico para el save (ej. attack_right).")
	if costs.is_empty() or values.is_empty():
		warnings.append("Rellena costs y values.")
	elif costs.size() != values.size():
		warnings.append("costs y values deben tener el mismo tamano.")
	return warnings


## Nivel actual desde UpgradeManager; max = largo de costs/values.
func sync_from_save() -> void:
	maximum_level = get_max_level()
	current_level = UpgradeManager.get_level(upgrade_id)


func get_max_level() -> int:
	return mini(costs.size(), values.size())


func get_cost(level_index: int) -> int:
	if level_index < 0 or level_index >= costs.size():
		return 0
	return costs[level_index]


func get_value(level_index: int) -> float:
	if level_index < 0 or level_index >= values.size():
		return 0.0
	return values[level_index]


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


## Visibilidad por desbloqueo y borde verde/rojo/amarillo.
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
	return "(%d/%d)" % [current_level, maximum_level]


func get_popup_price() -> String:
	if current_level < maximum_level:
		var owned = CurrencyManager.get_ore_amount(Ores.get_id(cost_ore))
		return "%d/%d" % [owned, get_current_price()]
	return "[color=ffe524]MAXED[/color]"


func format_variable(value: float) -> String:
	if Upgrades.get_display_type(upgrade_type) == Upgrades.OperationMode.PERCENT:
		return str(int(round(abs(value) * 100.0))) + "%"
	if Upgrades.get_display_type(upgrade_type) == Upgrades.OperationMode.MULTIPLIER:
		return "x%.1f" % value
	if is_equal_approx(value, roundf(value)):
		return "%d" % roundi(value)
	return "%.1f" % value


## Value que va en {value}: el de la proxima compra, o el ultimo si ya esta maxed.
func get_display_value() -> float:
	if values.is_empty():
		return 0.0
	if current_level < values.size():
		return values[current_level]
	return values[values.size() - 1]


func can_afford() -> bool:
	return CurrencyManager.can_afford_ore_type(cost_ore, get_current_price())


func get_current_price() -> int:
	return get_cost(current_level)


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
	if not UpgradeManager.purchase(self):
		return
	var previous_level = current_level
	current_level = UpgradeManager.get_level(upgrade_id)
	purchased.emit(self)
	if previous_level == 0:
		first_purchase.emit()
	if current_level == maximum_level:
		maxed_purchase.emit()


func _on_button_mouse_entered():
	SFX.play(Sound.BUTTON_HOVER)
	Springer.rotate(visuals, 18)
	item_popup.set_content(
		UpgradeManager.get_title(upgrade_type),
		UpgradeManager.get_description(upgrade_type, format_variable(get_display_value())),
		get_popup_progress(),
		get_popup_price()
	)
	item_popup.appear()


func _on_button_mouse_exited():
	item_popup.disappear()
