extends Control
class_name OffscreenMarker
## Circulo + icono. El layer lo mueve al borde; este nodo solo pinta.

@onready var ring: TextureRect = %Ring
@onready var icon: TextureRect = %Icon


func set_icon(texture: Texture2D) -> void:
	icon.texture = texture


func set_ring_color(color: Color) -> void:
	ring.modulate = color
