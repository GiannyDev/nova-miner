extends Control
class_name ScreenControl

@export var screen_size := Vector2i(1920, 1080)
@export var shrink_on_move: bool

var attached_to: Control
var attach_offset: Vector2

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func _process(_delta: float) -> void:
	if attached_to != null and is_instance_valid(attached_to):
		if not attached_to.is_inside_tree():
			detach()
		else:
			set_pos(attached_to.get_global_transform_with_canvas().origin + attach_offset)


func force_size_update() -> void:
	global_position = Vector2.ZERO
	size = Vector2.ZERO


func set_pos(pos: Vector2) -> void:
	force_size_update()
	pos.x = clamp(pos.x, 0, screen_size.x - size.x)
	pos.y = clamp(pos.y, 0, screen_size.y - size.y)
	global_position = round(pos)
	if shrink_on_move:
		offset_bottom = 0
		offset_right = 0

func center_above_pos(pos: Vector2, offset := Vector2.ZERO) -> void:
	force_size_update()
	pos.x -= floor(size.x / 2)
	pos.y -= size.y
	pos += offset
	set_pos(pos)


func center_above(control: Control, offset := Vector2.ZERO, use_scale := false) -> void:
	force_size_update()
	var new_pos: Vector2 = _get_pos(control, use_scale)
	new_pos.x += floor((control.size.x / 2) - size.x / 2)
	new_pos.y -= size.y
	new_pos += offset
	set_pos(new_pos)


func center_below(control: Control, offset := Vector2.ZERO, use_scale := false) -> void:
	force_size_update()
	var new_pos: Vector2 = _get_pos(control, use_scale)
	new_pos.x += floor((control.size.x / 2) - size.x / 2)
	new_pos.y += control.size.y
	new_pos += offset
	set_pos(new_pos)


## Get global position of given control.
## Set use_scale = false to ignore control's scale and rotation
func _get_pos(control: Control, use_scale: bool) -> Vector2:
	var pos: Vector2 = control.get_global_transform_with_canvas().origin
	if not use_scale:
		## Get unrotated pos
		var length: float = control.pivot_offset.length()
		var pivot_rangle: float = control.pivot_offset.angle()
		var total_rangle: float = pivot_rangle + control.rotation
		var offset: Vector2 = Vector2.from_angle(total_rangle) * length
		var pivot_offset_global_pos: Vector2 = pos + offset
		pos = pivot_offset_global_pos - control.pivot_offset
		
		## Get unscaled pos
		pos = pos + (offset * (control.scale - Vector2.ONE))
	return pos


## If there is enough space below, center below. Otherwise, center above
func center_below_or_above(control: Control, offset := Vector2.ZERO, use_scale := false) -> void:
	force_size_update()
	##Enough space below so center below
	if control.global_position.y + control.size.y + offset.y + size.y <= screen_size.y:
		center_below(control, offset, use_scale)
	else:
		center_above(control, offset, use_scale)


func center_above_or_below(control: Control, offset := Vector2.ZERO, use_scale := false) -> void:
	force_size_update()
	## Enough space above so center above
	if control.global_position.y - offset.y - size.y >= 0:
		center_above(control, offset, use_scale)
	else:
		center_below(control, offset, use_scale)


func attach(control: Control) -> void:
	attach_offset = get_global_transform_with_canvas().origin - control.get_global_transform_with_canvas().origin
	attached_to = control


func detach() -> void:
	attached_to = null
