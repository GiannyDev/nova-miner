extends RefCounted
class_name DampedSpring1D

var position: float = 0.0
var velocity: float = 0.0
var rest_pos: float = 0.0
var spring_const: float = 0.0
var damping_const: float = 0.0
var update_callback: Callable = Callable()


func _init(damping_ratio: float = 0.5, frequency: float = 12.0, p_rest_pos: float = 0.0) -> void:
	position = 0.0
	velocity = 0.0
	rest_pos = p_rest_pos
	spring_const = frequency * frequency
	damping_const = 2.0 * damping_ratio * frequency


func update(delta: float) -> void:
	var displacement := position - rest_pos
	var force := -damping_const * velocity - spring_const * displacement
	velocity += force * delta
	position += velocity * delta
	if not update_callback.is_null():
		update_callback.call(position)


func set_at(pos: float) -> DampedSpring1D:
	position = pos
	return self


func rest_at(p_rest_pos: float) -> DampedSpring1D:
	rest_pos = p_rest_pos
	return self


func callback(p_callback: Callable) -> DampedSpring1D:
	update_callback = p_callback
	return self
