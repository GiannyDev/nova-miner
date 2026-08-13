extends ScreenControl
class_name ItemPopup

@onready var title: Label = %Title
@onready var description: RichTextLabel = %Description
@onready var price: RichTextLabel = %Price

func appear(node: Control, above := true) -> void:
	show()
	global_position = Vector2(-3000, -3000)
	
	await get_tree().process_frame
	await get_tree().process_frame
	scale = Vector2.ONE
	rotation = 0
	
	if above:
		center_above_or_below(node, Vector2.UP * 10, false)
	else:
		center_below_or_above(node, Vector2.ZERO, false)
	Springer.squash(self, -0.2, 0.2, 1, 800, 19)
	Springer.rotate(self, 4)
