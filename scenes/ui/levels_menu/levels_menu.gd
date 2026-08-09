extends Control
class_name LevelMenu
## Panel de minas: fade + rotacion spring estilo ShellDiver al abrir.

@export var level_buttons: Array[Button]
@export var fade_duration: float = 0.35
@export var spring_rotate: float = 14.0

var rest_position: Vector2
var show_tween: Tween

func _ready() -> void:
	for btn: Button in level_buttons:
		btn.mouse_entered.connect(_on_btn_mouse_entered.bind(btn))
		btn.pressed.connect(_on_btn_pressed.bind(btn))
	
	visible = false
	rest_position = position
	modulate.a = 0.0
	rotation_degrees = 0.0


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("escape"):
		if visible: hide_panel()


func show_panel() -> void:
	GameManager.curr_state = GameManager.GameStates.PAUSED
	if show_tween != null and show_tween.is_valid():
		show_tween.kill()

	visible = true
	await get_tree().process_frame
	await get_tree().process_frame

	show_tween = create_tween()
	show_tween.set_parallel(true)
	show_tween.tween_property(self, "modulate:a", 1.0, fade_duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	Springer.rotate(self, spring_rotate)


func hide_panel() -> void:
	if show_tween != null and show_tween.is_valid():
		show_tween.kill()
	hide()
	modulate.a = 0.0
	rotation_degrees = 0.0
	position = rest_position
	GameManager.curr_state = GameManager.GameStates.PLAYING


func _on_btn_mouse_entered(button: Button) -> void:
	button.pivot_offset_ratio = Vector2(0.5, 0.5)
	Springer.rotate(button, 8)


func _on_btn_pressed(button: Button) -> void:
	button.pivot_offset_ratio = Vector2(0.5, 0.5)
	Springer.scale(button, -0.1)
