extends Resource
class_name DampedSpringData

@export_range(0.0, 1.0, 0.01) var damping_ratio: float = 0.5
@export_range(0.0, 40.0, 0.5) var frequency: float = 12.0
@export var intensity: float = 0.0
