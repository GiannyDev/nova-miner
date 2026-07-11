extends Node2D
class_name Ore

signal destroyed(ore: Ore)

@export var max_hp: float = 30.0

@onready var visuals: Node2D = $Visuals
@onready var sprite: Sprite2D = $Visuals/Sprite

var current_hp: float = 30.0
var grid: MineGrid
var grid_cell: Vector2i = Vector2i.ZERO
var is_destroyed: bool = false


func _ready() -> void:
	current_hp = max_hp


## Configura HP y celda del grid al spawnear.
func setup(hp: float, mine_grid: MineGrid = null, cell: Vector2i = Vector2i.ZERO) -> void:
	max_hp = hp
	current_hp = hp
	grid = mine_grid
	grid_cell = cell


func take_damage(amount: float) -> void:
	if is_destroyed or amount <= 0.0:
		return

	current_hp -= amount
	show_mine_animation()

	if current_hp <= 0.0:
		destroy()


func show_mine_animation() -> void:
	if visuals != null:
		Springer.squash(visuals, 0.1, -0.1)


func destroy() -> void:
	if is_destroyed:
		return
	is_destroyed = true

	if grid != null:
		grid.set_occupied(grid_cell, false)

	destroyed.emit(self)
	queue_free()
