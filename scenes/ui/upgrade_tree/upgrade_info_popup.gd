extends PanelContainer
class_name UpgradeInfoPopup

@onready var title_label: Label = %TitleLabel
@onready var description_label: RichTextLabel = %DescriptionLabel
@onready var left_stat: RichTextLabel = %LeftStat
@onready var stat_middle: RichTextLabel = %StatMiddle
@onready var right_stat: RichTextLabel = %RightStat
@onready var current_level_label: Label = %CurrentLevelLabel
@onready var level_middle: Label = %LevelMiddle
@onready var max_level_label: Label = %MaxLevelLabel
@onready var player_currency: RichTextLabel = %PlayerCurrency
@onready var cost_middle: RichTextLabel = %CostMiddle
@onready var cost_label: RichTextLabel = %Cost
@onready var dividing_line_2: ColorRect = %DividingLine2
@onready var dividing_line_3: ColorRect = %DividingLine3
@onready var dividing_line_4: ColorRect = %DividingLine4

var is_closing: bool = false
var hover_tween: Tween


func _ready() -> void:
	hide()


func setup_skill_text(
	upgrade_title: String,
	description: String,
	has_stats: bool,
	stat_1: String,
	stat_2: String,
	currency_amount: String,
	upgrade_cost: String,
	current_level: String = "",
	max_level: String = "",
	highlight_word: String = ""
) -> void:
	title_label.text = upgrade_title.to_upper()

	var description_text := description.to_upper()
	var upper_highlight := highlight_word.to_upper()
	if upper_highlight != "":
		var regex := RegEx.new()
		regex.compile("\\b" + upper_highlight + "\\b")
		description_text = regex.sub(
			description_text,
			"[color=#AB1E18]%s[/color]" % upper_highlight,
			true
		)

	description_label.text = "[center]%s[/center]" % description_text

	player_currency.show()
	cost_middle.show()
	cost_label.show()
	dividing_line_2.show()
	dividing_line_3.show()
	dividing_line_4.show()

	left_stat.hide()
	stat_middle.hide()
	right_stat.hide()

	left_stat.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_stat.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stat_middle.size_flags_horizontal = Control.SIZE_SHRINK_CENTER

	var is_maxed := upgrade_cost.to_upper() == "MAXED" or stat_2.to_upper() == "MAXED"

	if has_stats:
		left_stat.show()
		stat_middle.show()
		right_stat.show()
		left_stat.text = "[center][color=#1AE6FF]%s[/color][/center]" % stat_1.to_upper()
		stat_middle.text = "[center]>[/center]"
		if is_maxed:
			right_stat.text = "[center][color=#1A9CFF]MAXED[/color][/center]"
		else:
			right_stat.text = "[center][color=#1A9CFF]%s[/color][/center]" % stat_2.to_upper()
	elif stat_2.to_upper() == "MAXED" or is_maxed:
		stat_middle.show()
		stat_middle.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		stat_middle.text = "[center][color=#1A9CFF]MAXED[/color][/center]"

	if current_level != "" and max_level != "":
		current_level_label.text = current_level
		max_level_label.text = max_level

	player_currency.text = "[center][color=#8bff8d]%s[/color][/center]" % currency_amount
	cost_middle.text = "[center]/[/center]"

	if is_maxed:
		cost_label.text = "[center][color=#8bff8d]MAXED[/color][/center]"
	else:
		cost_label.text = "[center][color=#8bff8d]%s[/color][/center]" % upgrade_cost

	_update_popup_size(upgrade_title)


func _update_popup_size(raw_title_string: String) -> void:
	var font_char_width := 10.0
	var title_pixel_width := raw_title_string.length() * font_char_width
	var target_width := clampf(title_pixel_width, 180.0, 320.0)
	custom_minimum_size = Vector2.ZERO


func show_panel(anchor_pos: Vector2, button_size: Vector2, boundary_control: Control = null) -> void:
	is_closing = false
	modulate.a = 0.0
	show()

	await get_tree().process_frame
	await get_tree().process_frame

	if is_closing:
		return

	var panel_padding := Vector2(24.0, 24.0)
	pivot_offset = size / 2.0

	var limit_rect: Rect2
	if boundary_control != null and boundary_control.is_inside_tree():
		limit_rect = boundary_control.get_global_rect()
	else:
		limit_rect = get_viewport().get_visible_rect()

	var target_x := anchor_pos.x + button_size.x / 2.0 - size.x / 2.0
	var target_y := anchor_pos.y - size.y - 6.0

	if target_y < limit_rect.position.y:
		target_y = anchor_pos.y + button_size.y + 6.0

	target_x = clampf(target_x, limit_rect.position.x + 6.0, limit_rect.end.x - size.x - 6.0)
	target_y = clampf(target_y, limit_rect.position.y + 6.0, limit_rect.end.y - size.y - 6.0)

	global_position = Vector2(target_x, target_y).floor()
	modulate.a = 1.0
	_animate_panel()


func hide_panel() -> void:
	is_closing = true

	if hover_tween != null:
		hover_tween.kill()

	scale = Vector2.ONE
	rotation_degrees = 0.0
	hide()


func _animate_panel() -> void:
	if hover_tween != null:
		hover_tween.kill()

	scale = Vector2.ONE
	rotation_degrees = 0.0

	hover_tween = create_tween().set_parallel(true)
	hover_tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	hover_tween.tween_property(self, "scale", Vector2(1.1, 1.1), 0.1)
	hover_tween.tween_property(self, "rotation_degrees", 4.0, 0.1)
	hover_tween.chain()
	hover_tween.tween_property(self, "scale", Vector2.ONE, 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	hover_tween.tween_property(self, "rotation_degrees", 0.0, 0.6).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
