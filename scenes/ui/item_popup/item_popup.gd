extends ScreenControl
class_name ItemPopup
## Popup de un UpgradeNode. Vive en el espacio del nodo (sigue pan/zoom).

@export var lift := 34.0

@onready var title: Label = %Title
@onready var description: RichTextLabel = %Description
@onready var progress: RichTextLabel = %Progress
@onready var price: RichTextLabel = %Price

func _ready() -> void:
	super._ready()
	offset_transform_enabled = true
	offset_transform_pivot_ratio = Vector2(0.5, 0.5)
	hide()


func set_content(popup_title: String, popup_description: String, popup_progress: String, popup_price: String) -> void:
	title.text = popup_title
	description.text = popup_description
	progress.text = popup_progress
	price.text = popup_price


## Centra encima del padre (origen del Node2D) dejando `lift` entre el borde inferior y el origen.
func appear() -> void:
	show()
	size = Vector2.ZERO
	await get_tree().process_frame
	if not is_visible_in_tree():
		return
	position = Vector2(round(-size.x * 0.5), round(-size.y - lift))
	scale = Vector2.ONE
	rotation = 0.0
	Springer.rotate(self, 12)


func disappear() -> void:
	Springer.kill_on(self)
	scale = Vector2.ONE
	rotation = 0.0
	hide()
