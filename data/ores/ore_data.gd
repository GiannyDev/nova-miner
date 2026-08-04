extends Resource
class_name OreData

enum OreType {
	GOLD
}

@export var id: String
@export var ore_type: OreType
@export var currency_sprite: Texture2D
@export var definitions: Array[OreDefinition]
@export var refine_wait_time: float = 6.0
