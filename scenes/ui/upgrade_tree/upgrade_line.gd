extends Line2D
class_name UpgradeLine

var from_button: Control
var to_button: Control


func _process(_delta: float) -> void:
	if from_button == null or to_button == null:
		return

	clear_points()
	var point_a := to_local(from_button.get_global_rect().get_center())
	var point_b := to_local(to_button.get_global_rect().get_center())
	add_point(point_a)
	add_point(point_b)
