extends Node2D
class_name Ore

signal destroyed(ore: Ore)

@export_group("Combat")
@export var max_hp: float = 30.0
@export var ore_size: OreDefinition.OreSize = OreDefinition.OreSize.SMALL
## OreData del catalogo (id + icon). Si null al spawnear, el spawner asigna default.
@export var ore_data: OreData

@export_group("Performance")
## Apaga el collider al salir de pantalla. Ojo: un taladro fuera de vista tampoco podra golpearlo.
@export var cull_collision_offscreen: bool = false

@export_category("Images")
@export var texture_100: Texture2D
@export var texture_75: Texture2D
@export var texture_50: Texture2D
@export var texture_25: Texture2D

@onready var visuals: Node2D = $Visuals
@onready var sprite: Sprite2D = %Sprite
@onready var collision_shape: CollisionShape2D = $StaticBody2D/CollisionShape2D
@onready var damage_marker: Marker2D = $DamageMarker

var current_hp: float = 30.0
var grid: MineGrid
var grid_cell: Vector2i = Vector2i.ZERO
var stack_index: int = 0
var is_destroyed: bool = false
var spawn_tween: Tween
var screen_notifier: VisibleOnScreenNotifier2D


func _ready() -> void:
	current_hp = max_hp
	refresh_hp_sprite()
	ensure_screen_notifier()


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
	refresh_hp_sprite()


func take_damage(amount: float) -> void:
	if is_destroyed or amount <= 0.0:
		return

	current_hp -= amount
	show_mine_animation()
	refresh_hp_sprite()

	if current_hp <= 0.0:
		destroy()


func show_mine_animation() -> void:
	Springer.squash(visuals, 0.1, -0.1)


## Cambia el sprite segun el % de HP restante (100 / 75 / 50 / 25).
func refresh_hp_sprite() -> void:
	var ratio := current_hp / maxf(max_hp, 0.001)
	if ratio > 0.75:
		sprite.texture = texture_100
	elif ratio > 0.5:
		sprite.texture = texture_75
	elif ratio > 0.25:
		sprite.texture = texture_50
	else:
		sprite.texture = texture_25


## Marca el bloque como minado, suelta drops y avisa. El pool decide cuando reciclarlo.
func destroy() -> void:
	if is_destroyed:
		return
	is_destroyed = true

	if grid != null:
		grid.remove_stack_occupation(grid_cell)

	EventBus.run_ore_destroyed.emit(self)
	spawn_ore_drops()
	destroyed.emit(self)


## Contrato de pool: deja el bloque listo para volver a minarse.
func on_spawned() -> void:
	is_destroyed = false
	current_hp = max_hp
	visible = true
	scale = Vector2.ONE
	visuals.scale = Vector2.ONE
	refresh_hp_sprite()
	set_collision_enabled(true)


## Contrato de pool: lo apaga sin liberarlo (lo saca de vista y de la fisica).
func on_despawned() -> void:
	kill_spawn_tween()
	visible = false
	set_collision_enabled(false)
	grid = null


## "Plop" de aparicion mid-run. El tween vive en el bloque para poder matarlo al reciclarlo.
func play_spawn_animation(duration: float) -> void:
	kill_spawn_tween()

	if duration <= 0.0:
		scale = Vector2.ONE
		return

	scale = Vector2.ZERO
	spawn_tween = create_tween()
	spawn_tween.tween_property(self, "scale", Vector2.ONE, duration)\
		.set_trans(Tween.TRANS_BACK)\
		.set_ease(Tween.EASE_OUT)


## Deja el bloque aplastado en Y (crece desde el piso en la intro).
func prepare_intro_collapsed() -> void:
	kill_spawn_tween()
	scale = Vector2(1.0, 0.0)


## Crece de abajo hacia arriba (origen del ore = pies).
func play_rise_animation(duration: float) -> void:
	kill_spawn_tween()
	scale = Vector2(1.0, 0.0)
	spawn_tween = create_tween()
	spawn_tween.tween_property(self, "scale:y", 1.0, duration)\
		.set_trans(Tween.TRANS_BACK)\
		.set_ease(Tween.EASE_OUT)


## Spawnea 1/2/3 drops visuales segun el size del ore (no es la cantidad de inventario).
func spawn_ore_drops() -> void:
	var drop_count := get_drop_visual_count()
	var spawn_pos := global_position
	var parent := get_parent()
	if parent == null:
		return

	for i in drop_count:
		var drop: OreDrop = Refs.ORE_DROP_SCENE.instantiate()
		parent.add_child(drop)
		drop.setup(spawn_pos, ore_data, 1)


# --- Private helpers (no leading _) ---
## set_deferred porque el bloque puede apagarse dentro de un callback de fisica.
func set_collision_enabled(enabled: bool) -> void:
	if collision_shape == null:
		return
	collision_shape.set_deferred(&"disabled", not enabled)


func kill_spawn_tween() -> void:
	if spawn_tween != null and spawn_tween.is_valid():
		spawn_tween.kill()
	spawn_tween = null


## Notifier opt-in: solo se crea si el culling esta activado, asi cuesta cero cuando no se usa.
func ensure_screen_notifier() -> void:
	if not cull_collision_offscreen or screen_notifier != null:
		return

	screen_notifier = VisibleOnScreenNotifier2D.new()
	screen_notifier.rect = get_visual_rect()
	add_child(screen_notifier)
	screen_notifier.screen_entered.connect(_on_screen_entered)
	screen_notifier.screen_exited.connect(_on_screen_exited)


## Rect local que cubre el sprite del bloque (base del notifier).
func get_visual_rect() -> Rect2:
	if sprite == null or sprite.texture == null:
		return Rect2(-128.0, -384.0, 256.0, 384.0)

	var size := sprite.texture.get_size() * sprite.scale
	return Rect2(sprite.position - size * 0.5, size)


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


func is_alive() -> bool:
	return not is_destroyed


# --- Signal callbacks ---
func _on_screen_entered() -> void:
	if not is_destroyed:
		set_collision_enabled(true)


func _on_screen_exited() -> void:
	set_collision_enabled(false)
