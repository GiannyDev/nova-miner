extends Resource
class_name OreData

@export var id: String
## Tipo de ore (dropdown Ores). Debe coincidir con id de catalogo.
@export var ore_type: int = Ores.GOLD
@export var currency_sprite: Texture2D
@export var definitions: Array[OreDefinition]
@export var refine_wait_time: float = 6.0
