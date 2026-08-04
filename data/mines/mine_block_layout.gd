extends Resource
class_name MineBlockLayout
## Tamano del sprite del bloque y de la celda del grid (XY no cuadrado).

@export_group("Block Sprite")
## Ancho del sprite/bloque individual en pixeles.
@export var block_width: int = 128
## Alto del sprite/bloque individual en pixeles.
@export var block_height: int = 144

@export_group("Grid Cell")
## Tamano de cada celda del grid (X = ancho footprint, Y = paso de apilado).
@export var cell_size: Vector2i = Vector2i(128, 62) : set = set_cell_size

@export_group("Placement")
## Desde el centro Y de la celda, cuantas unidades bajar el OreBlock (positivo = abajo).
@export var cell_center_offset_y: float = 31.0


## Tamano del bloque como Vector2i (ancho x alto del sprite).
func get_block_size() -> Vector2i:
	return Vector2i(block_width, block_height)


## Paso vertical entre ores apilados = alto de celda (62 por defecto).
func get_stack_rise_y() -> float:
	return float(cell_size.y)


## Offset mundo del OreBlock: centro de celda + bajar 31 + rise por stack_index.
func get_stack_offset(stack_index: int = 0) -> Vector2:
	var rise := get_stack_rise_y() * float(maxi(stack_index, 0))
	return Vector2(0.0, cell_center_offset_y - rise)


func set_cell_size(value: Vector2i) -> void:
	cell_size = Vector2i(maxi(value.x, 1), maxi(value.y, 1))
