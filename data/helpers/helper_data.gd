extends Resource
class_name HelperData
## Look y wander de un ayudante. Velocidad/daño/count viven en Stats.

@export var id: String = "miner"
## Cara del icono de borde y del sprite en mina.
@export var icon: Texture2D
## Placeholder de color hasta tener sprite propio.
@export var tint: Color = Color(0.35, 0.82, 0.95, 1.0)
## Segundos entre golpes al minar un bloque que no muere de un golpe.
@export var hit_delay: float = 0.35

@export_group("Wander")
## Minimo entre giros de heading.
@export var heading_seconds_min: float = 0.45
## Maximo entre giros de heading.
@export var heading_seconds_max: float = 1.35
