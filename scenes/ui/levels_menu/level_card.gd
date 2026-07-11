extends HBoxContainer
class_name LevelCard

@export var floor_1_button: Button
@export var floor_2_button: Button
@export var floor_3_button: Button
@export var completion_next_level: LevelCard
@export var level_data: LevelData

var curr_floor_data: FloorData

func _ready() -> void:
	if not floor_1_button or not floor_2_button or not floor_3_button or not level_data: return
	floor_1_button.pressed.connect(_on_floor_selected.bind(level_data.floor_1_data))
	floor_2_button.pressed.connect(_on_floor_selected.bind(level_data.floor_2_data))
	floor_3_button.pressed.connect(_on_floor_selected.bind(level_data.floor_3_data))
	
	floor_1_button.mouse_entered.connect(on_floor_button_mouse_entered.bind(floor_1_button))
	floor_2_button.mouse_entered.connect(on_floor_button_mouse_entered.bind(floor_2_button))
	floor_3_button.mouse_entered.connect(on_floor_button_mouse_entered.bind(floor_3_button))

## Funcion que muestra el transition
## carga MineZone inyectando FloorDataw
func _on_floor_selected(data: FloorData) -> void:
	curr_floor_data = data
	
	await Transition.fade_out(1.0)
	get_tree().change_scene_to_file("res://scenes/zones/mine_zone/mine_zone.tscn")
	await Transition.fade_in(1.0)

func on_floor_button_mouse_entered(btn: Button) -> void:
	floor_1_button.get_child(0).visible = false
	floor_2_button.get_child(0).visible = false
	floor_3_button.get_child(0).visible = false
	btn.get_child(0).visible = true
