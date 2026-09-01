extends Node

var live_dust_bits: int = 0


## Rayo de hop: glow = `width`/`color`. El efecto se destruye solo (travel + hold).
func electricity(pos: Vector2, to: Vector2, color: Color, width: float = 16.0, duration: float = 0.2) -> ElectricityEffect:
	if Refs.mine_zone == null:
		return null
	var jitter := maxf(width * 0.55, 12.0)
	var effect := ElectricityEffect.new(pos, to, color, width, jitter)
	effect.hold_duration = maxf(duration, 0.12)
	Refs.mine_zone.add_child(effect, true)
	effect.global_position = pos
	return effect


## Flash de explosion en world space. El blast del spawner lo llama; no es un bloque.
func explosion(pos: Vector2, radius_px: float, color: Color = Color(1.0, 0.42, 0.12, 0.8)) -> ExplosionEffect:
	if Refs.mine_zone == null:
		return null
	var effect := ExplosionEffect.new(pos, radius_px, color)
	Refs.mine_zone.add_child(effect, true)
	effect.global_position = pos
	return effect


## Polvo al romper. Respeta atmosphere.dust_max_live. Color del bloque (tierra / mineral).
func break_dust(world_pos: Vector2, color: Color, count: int = 5) -> void:
	if Refs.mine_zone == null:
		return
	var cap := 28
	if Refs.mine_zone.atmosphere != null:
		cap = Refs.mine_zone.atmosphere.dust_max_live
	var spawn_count := mini(count, cap - live_dust_bits)
	for i in spawn_count:
		var bit := BreakDustBit.new(world_pos, color)
		live_dust_bits += 1
		bit.finished.connect(on_dust_bit_finished)
		Refs.mine_zone.add_child(bit, true)
		bit.global_position = world_pos + Vector2(randf_range(-18.0, 18.0), randf_range(-40.0, 8.0))


func on_dust_bit_finished() -> void:
	live_dust_bits = maxi(live_dust_bits - 1, 0)
