extends Node

func electricity(pos: Vector2, to: Vector2, color: Color, width: float = 16.0, duration: float = 0.2) -> ElectricityEffect:
	var effect := ElectricityEffect.new(pos, to, color, width)
	Refs.mine_zone.add_child(effect, true)
	effect.tween_width(0.0, duration).finished.connect(effect.queue_free)
	return effect


## Flash de explosion en world space. El blast del spawner lo llama; no es un bloque.
func explosion(pos: Vector2, radius_px: float, color: Color = Color(1.0, 0.42, 0.12, 0.8)) -> ExplosionEffect:
	if Refs.mine_zone == null:
		return null
	var effect := ExplosionEffect.new(pos, radius_px, color)
	Refs.mine_zone.add_child(effect, true)
	effect.global_position = pos
	return effect
