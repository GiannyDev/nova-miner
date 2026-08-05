extends Resource
class_name OreSpawnEntry
## Un ore posible de una mina con su peso relativo de aparicion.

## OreData del catalogo (id + icon + definiciones por size).
@export var ore_data: OreData
## Peso relativo frente a las otras entradas. 2.0 aparece el doble que 1.0.
@export_range(0.0, 100.0, 0.1, "or_greater") var weight: float = 1.0
