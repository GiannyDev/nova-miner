@tool
extends Panel
class_name StatDisplay
## Fila de stat del recap. Los timings los empuja RecapMenu (padre) via configure_from_parent.

enum DisplayMode { COMPACT_NUMBER, DISTANCE, PLAIN_INT }

@export var reveal_style: StringName = &"shell_diver"

@onready var name_label: Label = %Name
@onready var value_label: Label = %Value

var juice_preset: JuicePreset
var value_spring: float = 0.12
var rest_position: Vector2
var translation_key: String = ""
var display_mode: DisplayMode = DisplayMode.COMPACT_NUMBER
var target_value: float = 0.0
var is_revealed: bool = false


func _ready() -> void:
	if not Engine.is_editor_hint():
		reset_hidden()


## RecapMenu empuja estilo + preset + spring antes de reset/reveal.
func configure_from_parent(style: StringName, preset: JuicePreset, spring: float) -> void:
	reveal_style = style
	juice_preset = preset
	value_spring = spring


func setup(key: String, value: float, mode: DisplayMode = DisplayMode.COMPACT_NUMBER) -> void:
	translation_key = key
	target_value = value
	display_mode = mode
	name_label.text = tr(key) + " :"
	value_label.text = format_value(0.0, mode)


func reset_hidden() -> void:
	is_revealed = false
	modulate.a = 0.0
	scale = Vector2.ONE
	rotation_degrees = 0.0
	await get_tree().process_frame
	rest_position = position
	if reveal_style == &"forager":
		UIJuice.reset_forager(self, rest_position)
	else:
		UIJuice.reset_shell_diver(self, rest_position, juice_preset)


func reveal(host: Node, stagger_index: int = 0) -> void:
	if is_revealed:
		return
	is_revealed = true
	var cfg := UIJuice.resolve_preset(juice_preset)
	var delay := cfg.stagger_delay * float(stagger_index)
	if delay > 0.0:
		await host.get_tree().create_timer(delay).timeout

	var entry_tween: Tween
	if reveal_style == &"forager":
		entry_tween = UIJuice.animate_forager_pop_in(host, self, rest_position, juice_preset)
	else:
		entry_tween = UIJuice.animate_shell_diver_in(host, self, rest_position, juice_preset)
	await entry_tween.finished

	var count_tween := UIJuice.animate_count_up(host, value_label, 0.0, target_value, Callable(self, "format_current_value"), juice_preset)
	await count_tween.finished
	if value_spring > 0.0:
		Springer.scale(value_label, value_spring, 1.0)


func format_current_value(value: float) -> String:
	return format_value(value, display_mode)


static func format_value(value: float, mode: DisplayMode) -> String:
	match mode:
		DisplayMode.DISTANCE:
			return "%.0fm" % value
		DisplayMode.PLAIN_INT:
			return str(int(round(value)))
		_:
			return format_compact(value)


static func format_compact(value: float) -> String:
	var abs_value := absf(value)
	if abs_value >= 1_000_000.0:
		return "%.1fM" % (value / 1_000_000.0)
	if abs_value >= 1_000.0:
		return "%.0fK" % (value / 1_000.0)
	if is_equal_approx(value, round(value)):
		return str(int(round(value)))
	return str(snapped(value, 0.1))


func play_hover_juice() -> void:
	UIJuice.prepare_pivot(self)
	Springer.rotate(self, 300.0 / maxf(size.x, size.y))
