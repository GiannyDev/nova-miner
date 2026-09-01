extends Resource
class_name MineAtmosphere
## Oscuridad, linterna, borde de tunel y polvo al romper. Sin arte de piso.

@export_group("Darkness")
## Tinte del canvas de la mina. Mas bajo = mas cueva. La UI (CanvasLayer) no se ve afectada.
@export var canvas_modulate: Color = Color(0.22, 0.24, 0.32, 1.0)

@export_group("Torch")
@export var torch_color: Color = Color(1.0, 0.82, 0.52, 1.0)
@export var torch_energy: float = 2.35
@export var torch_texture_scale: float = 5.4
## Oscilacion de energia (linterna viva).
@export var torch_flicker_energy: float = 0.18
@export var torch_flicker_scale: float = 0.08
@export var torch_flicker_speed: float = 7.5

@export_group("Tunnel")
@export var rim_color: Color = Color(0.22, 0.14, 0.09, 0.95)
@export var rim_highlight: Color = Color(0.42, 0.28, 0.16, 0.35)
## Grosor del borde hacia un bloque solido, en fraccion del radio de celda.
@export_range(0.08, 0.45, 0.01) var rim_inset: float = 0.22

@export_group("Break Dust")
@export var dust_bits_dirt: int = 3
@export var dust_bits_mineral: int = 7
@export var dust_max_live: int = 28
@export var dust_color_dirt: Color = Color(0.45, 0.38, 0.32, 1.0)
