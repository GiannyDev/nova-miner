extends PointLight2D
class_name TorchLight
## Linterna del miner. Oscila energia/escala; MineAtmosphere manda color y radio.

var base_energy: float = 1.65
var base_texture_scale: float = 3.2
var flicker_energy: float = 0.18
var flicker_scale: float = 0.08
var flicker_speed: float = 7.5
var flicker_phase: float = 0.0


func _ready() -> void:
	flicker_phase = randf() * TAU
	set_process(true)


func _process(delta: float) -> void:
	flicker_phase += delta * flicker_speed
	var wobble := sin(flicker_phase) * 0.55 + sin(flicker_phase * 2.37) * 0.45
	energy = maxf(base_energy + wobble * flicker_energy, 0.2)
	texture_scale = maxf(base_texture_scale + wobble * flicker_scale, 0.4)


## Copia knobs del atmosphere. Llamar al entrar a la mina.
func apply_atmosphere(atmosphere: MineAtmosphere) -> void:
	if atmosphere == null:
		return
	scale = Vector2.ONE
	color = atmosphere.torch_color
	base_energy = atmosphere.torch_energy
	base_texture_scale = atmosphere.torch_texture_scale
	flicker_energy = atmosphere.torch_flicker_energy
	flicker_scale = atmosphere.torch_flicker_scale
	flicker_speed = atmosphere.torch_flicker_speed
	energy = base_energy
	texture_scale = base_texture_scale
	enabled = true
	visible = true
