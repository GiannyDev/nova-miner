extends Panel
class_name StatDisplay
## Fila de stat del recap. Panel primero (sin texto); el texto lo revela RecapMenu en cadena.

enum DisplayMode { COMPACT_NUMBER, DISTANCE, PLAIN_INT }

@onready var name_label: Label = $Margin/HBox/Name
@onready var value_label: Label = $Margin/HBox/Value

var rest_position: Vector2
var display_mode: DisplayMode = DisplayMode.COMPACT_NUMBER
var target_value: float = 0.0


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	reset_hidden()


func setup(key: String, value: float, mode: DisplayMode = DisplayMode.COMPACT_NUMBER) -> void:
	target_value = value
	display_mode = mode
	name_label.text = tr(key) + " :"
	value_label.text = format_value(0.0, mode)
	hide_texts()


func reset_hidden() -> void:
	modulate.a = 0.0
	scale = Vector2.ONE
	rest_position = position
	hide_texts()
	value_label.text = format_value(0.0, display_mode)


func hide_texts() -> void:
	name_label.modulate.a = 0.0
	value_label.modulate.a = 0.0


## Aparece el panel; los labels siguen ocultos.
func show_panel(host: Node, duration: float) -> void:
	position = rest_position
	scale = Vector2(0.92, 0.92)
	modulate.a = 0.0
	hide_texts()
	var tween := host.get_tree().create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "modulate:a", 1.0, duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "scale", Vector2.ONE, duration).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## Muestra name+value y count-up del numero.
func show_text(host: Node, duration: float) -> void:
	name_label.modulate.a = 1.0
	value_label.modulate.a = 1.0
	value_label.text = format_value(0.0, display_mode)
	var label := value_label
	var mode := display_mode
	var tween := host.get_tree().create_tween()
	tween.tween_method(
		func(value: float) -> void: label.text = format_value(value, mode),
		0.0,
		target_value,
		duration
	).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	await tween.finished
	Springer.scale(value_label, 0.12, 1.0)


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
	pivot_offset = size * 0.5
	Springer.rotate(self, 300.0 / maxf(size.x, size.y))
