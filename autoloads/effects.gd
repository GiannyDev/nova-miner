extends Node

func electricity(pos: Vector2, to: Vector2, color: Color, width: float = 16.0, duration: float = 0.2) -> ElectricityEffect:
	var effect := ElectricityEffect.new(pos, to, color, width)
	Refs.mine_zone.add_child(effect, true)
	effect.tween_width(0.0, duration).finished.connect(effect.queue_free)
	return effect
