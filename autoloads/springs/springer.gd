extends Node

var scale_springs: Dictionary = {}

# Key: target; Value: Dictionary (Key: NodePath; Value: Spring)
# Maintains 1 spring per property, on any number of properties on a target.
var target_springs: Dictionary = {}

var springs_list: Array = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

func _process(delta: float) -> void:
	var keys: Array = scale_springs.keys()
	for i: int in keys.size():
		if not is_instance_valid(keys[i]):
			scale_springs.erase(keys[i])
			continue
		var target: Object = keys[i]
		var spr: Spring = scale_springs[target]
		spr.update(delta)
		if is_zero_approx(spr.v) or spr.is_killed:
			scale_springs.erase(target)
		elif target is Node2D:
			(target as Node2D).scale = Vector2(spr.x, spr.x)
		elif target is Control:
			(target as Control).scale = Vector2(spr.x, spr.x)
	
	keys = target_springs.keys()
	for target in keys:
		if not is_instance_valid(target):
			target_springs.erase(target)
			continue
		var property_dict: Dictionary = target_springs[target]
		var property_dict_keys: Array = property_dict.keys()
		for property: NodePath in property_dict_keys:
			var spr: Spring = property_dict[property]
			spr.update(delta)
			spr.target.set_indexed(spr.property, spr.x)
			if spr.is_killed:
				property_dict.erase(property)
		if property_dict.is_empty():
			target_springs.erase(target)
	
	for i: int in range(springs_list.size()-1,-1,-1):
		var spring: Spring = springs_list[i]
		if not spring.is_killed:
			spring.update(delta)
		if spring.target and is_instance_valid(spring.target):
			spring.target.set_indexed(spring.property, spring.x)
		if spring.is_killed:
			springs_list.remove_at(i)

# Apply spring scale to target. Fire and forget
func scale(target: Object, force: float, x: float = 1, stiffness: float = 250,
dampening: float = 12) -> Spring:
	var spr: Spring
	if scale_springs.has(target):
		spr = scale_springs[target]
		spr.target_x = x
		spr.stiffness = stiffness
		spr.dampening = dampening
		spr.is_killed = false
		spr.pull(force)
	else:
		spr = Spring.new(x, stiffness, dampening)
		scale_springs[target] = spr
		spr.pull(force)
	return spr

# Return auto updating Spring object to be used however
func create(x: float = 1, stiffness: float = 150, dampening: float = 10) -> Spring:
	var spr: Spring = Spring.new(x, stiffness, dampening)
	springs_list.append(spr)
	
	return spr

func spring_property(target: Object, property: NodePath, force: float,
x: float = 0, stiffness: float = 150, dampening: float = 10) -> Spring:
	var spr: Spring
	if not target_springs.has(target):
		target_springs[target] = {}
	
	var property_dict: Dictionary = target_springs[target]
	if property_dict.has(property):
		spr = target_springs[target][property]
		spr.target_x = x
		spr.stiffness = stiffness
		spr.dampening = dampening
		spr.is_killed = false
	else:
		spr = Spring.new(x, stiffness, dampening)
		spr.attach(target, property)
		target_springs[target][property] = spr
	spr.pull(force)
	return spr

func rotate(target: Node, force: float, x: float = 0, stiffness: float = 600,
dampening: float = 14) -> Spring:
	var property: NodePath
	if target is Node2D or target is Control: property = "rotation_degrees"
	else: assert(false, "Invalid target given to Springer.rotate()")
	var spr: Spring = spring_property(target, property, force, x, stiffness, dampening)
	spr.set_range(-100, 100)
	return spr

func squash(target: Object, x_force: float, y_force: float, x: float = 1,
stiffness: float = 250, dampening: float = 12) -> void:
	spring_property(target, "scale:x", x_force, x, stiffness, dampening)
	spring_property(target, "scale:y", y_force, x, stiffness, dampening)

func cleanup() -> void:
	scale_springs.clear()
	springs_list.clear()
