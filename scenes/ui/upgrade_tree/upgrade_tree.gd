extends Control
class_name UpgradeTree

@export var content: Control
@export var lines_container: Node2D

@onready var currency_label: RichTextLabel = $Header/CurrencyLabel
@onready var buttons: Control = $TreeViewport/Content/Buttons
@onready var maxed_message: PanelContainer = $MaxedMessage

var dragging: bool = false
var zoom: float = 1.0
var min_zoom: float = 0.25
var max_zoom: float = 1.0
var zoom_step: float = 0.1
var skill_info: UpgradeInfoPopup = null


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


func open() -> void:
	visible = true
	setup_buttons()
	_update_currency_label()


func close() -> void:
	if skill_info != null:
		skill_info.hide_panel()
	visible = false


func setup_buttons() -> void:
	var upgrade_nodes: Array[UpgradeNode] = []

	for child in buttons.get_children():
		if child is UpgradeNode:
			if child.tree == null:
				child.tree = self
			if child.lines == null:
				child.lines = lines_container
			upgrade_nodes.append(child)

	for node in upgrade_nodes:
		if node.upgrade == null:
			continue
		node.level = GameManager.skill_levels.get(node.upgrade.skill_id, 0)
		node.max_level = node.upgrade.upgrade_stats.size()
		if node.icon_tex != null:
			node.skill_icon.texture = node.icon_tex
		node._set_upgrade_stats(node.level)

	for node in upgrade_nodes:
		node.check_prerequisites()
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
	var all_maxed := true

	for child in buttons.get_children():
		if child is UpgradeNode:
			child.update_line()
			if child.level < child.max_level:
				all_maxed = false

	if all_maxed and buttons.get_child_count() > 0:
		maxed_message.show()
	else:
		maxed_message.hide()


func _update_currency_label() -> void:
	var money: int = CurrencyManager.currency_data.currency_amount.get(
		CurrencyData.CurrencyType.MONEY, 0
	)
	currency_label.text = "[center][color=#8bff8d]CREDITS: %d[/color][/center]" % money


func _input(event: InputEvent) -> void:
	if not visible:
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
