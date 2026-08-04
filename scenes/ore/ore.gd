extends Node2D
class_name Ore
## Bloque minable individual. Solo se mueve este nodo padre; Visuals/collider quedan fijos en la escena.

signal destroyed(ore: Ore)

# --- Exports ---
@export_group("Combat")
@export var max_hp: float = 30.0
@export var ore_size: OreDefinition.OreSize = OreDefinition.OreSize.SMALL
## OreData del catalogo (id + icon). Si null al spawnear, el spawner asigna default.
@export var ore_data: OreData

# --- Onready / cached ---
@onready var visuals: Node2D = $Visuals

# --- Runtime ---
var current_hp: float = 30.0
var grid: MineGrid
var grid_cell: Vector2i = Vector2i.ZERO
var stack_index: int = 0
var is_destroyed: bool = false


# --- Built-ins ---
func _ready() -> void:
	current_hp = max_hp


# --- Public API ---
## Configura HP, size, celda, stack y OreData al spawnear.
func setup(
	hp: float,
	mine_grid: MineGrid,
	cell: Vector2i,
	size: OreDefinition.OreSize = OreDefinition.OreSize.SMALL,
	stack: int = 0,
	data: OreData = null
) -> void:
	max_hp = hp
	current_hp = hp
	grid = mine_grid
	grid_cell = cell
	ore_size = size
	stack_index = stack
	if data != null:
		ore_data = data


func take_damage(amount: float) -> void:
	if is_destroyed or amount <= 0.0:
		return

	current_hp -= amount
	show_mine_animation()

	if current_hp <= 0.0:
		destroy()


func show_mine_animation() -> void:
	Springer.squash(visuals, 0.1, -0.1)


func destroy() -> void:
	if is_destroyed:
		return
	is_destroyed = true

	if grid != null:
		grid.remove_stack_occupation(grid_cell)
	spawn_ore_drops()
	destroyed.emit(self)
	queue_free()


## Spawnea 1/2/3 drops visuales segun el size del ore (no es la cantidad de inventario).
func spawn_ore_drops() -> void:
	var drop_count := get_drop_visual_count()
	var spawn_pos := global_position

	for i in drop_count:
		var drop: OreDrop = Refs.ORE_DROP_SCENE.instantiate()
		get_parent().add_child(drop)
		drop.setup(spawn_pos, ore_data, 1)


# --- Bool / queries ---
func get_drop_visual_count() -> int:
	match ore_size:
		OreDefinition.OreSize.SMALL:
			return 1
		OreDefinition.OreSize.MEDIUM:
			return 2
		OreDefinition.OreSize.LARGE:
			return 3
	return 1
