extends RefCounted
class_name DampedSpring2D

var x: DampedSpring1D
var y: DampedSpring1D
var update_callback: Callable


func _init(damping_ratio, frequency, rest_pos: Vector2 = Vector2.ZERO):
	x = DampedSpring1D.new(damping_ratio, frequency, rest_pos.x)
	y = DampedSpring1D.new(damping_ratio, frequency, rest_pos.y)


func update(delta):
	x.update(delta)
	y.update(delta)

	if not update_callback.is_null():
		update_callback.callv([get_position()])


func rest_at(rest_pos: Vector2) -> DampedSpring2D:
	x.rest_at(rest_pos.x)
	y.rest_at(rest_pos.y)
	return self


func callback(_callback: Callable) -> DampedSpring2D:
	update_callback = _callback
	return self


func get_position() -> Vector2:
	return Vector2(x.position, y.position)


func get_velocity() -> Vector2:
	return Vector2(x.velocity, y.velocity)


func get_rest_pos() -> Vector2:
	return Vector2(x.rest_pos, y.rest_pos)


func set_position(pos: Vector2):
	x.position = pos.x
	y.position = pos.y


func set_velocity(vel: Vector2):
	x.velocity = vel.x
	y.velocity = vel.y


func reset(pos: Vector2):
	rest_at(pos)
	set_position(pos)
