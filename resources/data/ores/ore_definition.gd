extends Resource
class_name OreDefinition

enum OreSize { SMALL, MEDIUM, LARGE }

@export var sprite: Texture2D
@export var hp: float
@export var ore_size: OreSize = OreSize.SMALL


## Cuantas celdas del grid ocupa este ore (1x1, 2x2, 3x3).
func get_footprint() -> int:
	match ore_size:
		OreSize.SMALL:
			return 1
		OreSize.MEDIUM:
			return 2
		OreSize.LARGE:
			return 3
	return 1
