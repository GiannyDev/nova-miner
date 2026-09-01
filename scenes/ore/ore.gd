extends Node2D
class_name Ore

signal destroyed(ore: Ore)

@export var max_hp: float = 30.0
@export var ore_size: OreDefinition.OreSize = OreDefinition.OreSize.SMALL
@export var ore_data: OreData
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
@onready var collision_shape_top: CollisionShape2D = $StaticBody2D2/CollisionShape2D
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
	hp: float, mine_grid: MineGrid, cell: Vector2i, size: OreDefinition.OreSize = OreDefinition.OreSize.SMALL, stack: int = 0, data: OreData = null) -> void:
	max_hp = hp
	current_hp = hp
	grid = mine_grid
	grid_cell = cell
	ore_size = size
	stack_index = stack
	if data != null:
		ore_data = data
	refresh_hp_sprite()
	apply_block_look()


## Golpe no letal: squash + sprite. Letal → destroy sin FX.
func take_damage(amount: float) -> void:
	if is_destroyed or amount <= 0.0:
		return

	current_hp -= amount
	if current_hp <= 0.0:
		destroy()
		return

	Springer.squash(visuals, 0.1, -0.1)
	refresh_hp_sprite()


## Kill sin squash (mismo destroy; el squash solo ocurre en chips no letales).
func destroy_instant() -> void:
	destroy()


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
	if is_destroyed: return
	is_destroyed = true

	# Hide + cortar tweens YA. Si el pool reusa esta instancia, no debe interpolar desde aqui.
	kill_spawn_tween()
	Springer.kill_on(visuals)
	Springer.kill_on(self)
	visible = false
	set_collision_enabled(false)
	reset_physics_interpolation()

	if grid != null:
		grid.remove_stack_occupation(grid_cell)

	EventBus.run_ore_destroyed.emit(self)
	if is_mineral():
		spawn_ore_drops()
	destroyed.emit(self)


## Contrato de pool: stats/colliders listos. Visible lo pone el spawner DESPUES de teleportear.
func on_spawned() -> void:
	is_destroyed = false
	current_hp = max_hp
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	visible = false
	scale = Vector2.ONE
	if visuals != null:
		visuals.scale = Vector2.ONE
	refresh_hp_sprite()
	apply_block_look()
	set_collision_enabled(true)
	reset_physics_interpolation()


## Contrato de pool: lo apaga sin liberarlo (lo saca de vista y de la fisica).
func on_despawned() -> void:
	kill_spawn_tween()
	Springer.kill_on(visuals)
	Springer.kill_on(self)
	visible = false
	if sprite != null:
		sprite.modulate = Color.WHITE
	set_collision_enabled(false)
	reset_physics_interpolation()
	grid = null


## Visible a escala 1, sin pop-in (revelado mid-run / fuera de camara).
func show_instantly() -> void:
	kill_spawn_tween()
	scale = Vector2.ONE
	visible = true
	reset_physics_interpolation()


## "Plop" de aparicion. Solo intro si el spawner lo pide; mid-run usa show_instantly.
func play_spawn_animation(duration: float) -> void:
	kill_spawn_tween()
	reset_physics_interpolation()

	if duration <= 0.0:
		scale = Vector2.ONE
		visible = true
		return

	scale = Vector2.ZERO
	visible = true
	spawn_tween = create_tween()
	spawn_tween.tween_property(self, "scale", Vector2.ONE, duration)\
		.set_trans(Tween.TRANS_BACK)\
		.set_ease(Tween.EASE_OUT)


## Deja el bloque aplastado en Y (crece desde el piso en la intro).
func prepare_intro_collapsed() -> void:
	kill_spawn_tween()
	scale = Vector2(1.0, 0.0)
	visible = true
	reset_physics_interpolation()


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
## Disable inmediato al destruir (anti-teleporte). Enable deferred es seguro al reciclar.
func set_collision_enabled(enabled: bool) -> void:
	set_shape_enabled(collision_shape, enabled)
	set_shape_enabled(collision_shape_top, enabled)


func set_shape_enabled(shape: CollisionShape2D, enabled: bool) -> void:
	if shape == null:
		return
	if enabled:
		shape.set_deferred(&"disabled", false)
	else:
		shape.disabled = true


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


## Tierra al paso: HP lleno que muere de este golpe. Un bloque ya picado nunca es oneshot.
func is_oneshot_for(damage: float) -> bool:
	return is_alive() and current_hp <= damage and current_hp >= max_hp - 0.001


## Tierra de cueva: se perfora, no dropea mineral.
func is_dirt() -> bool:
	return ore_data != null and ore_data.is_dirt


## Bomba: mismo collider/HP; al morir el spawner dispara el blast.
func is_bomb() -> bool:
	return ore_data != null and ore_data.is_bomb


## Mineral de bag: ni tierra ni bomba.
func is_mineral() -> bool:
	return not is_dirt() and not is_bomb()


## Color del polvo al romper: tint del mineral o el modulate de tierra.
func get_break_dust_color() -> Color:
	if sprite != null:
		return sprite.modulate
	if ore_data != null:
		return ore_data.tint
	return Color(0.48, 0.42, 0.38, 1.0)


## Tierra mas oscura; bomba usa tint del OreData; mineral queda blanco.
func apply_block_look() -> void:
	if sprite == null:
		return
	if is_dirt():
		sprite.modulate = Color(0.48, 0.42, 0.38)
		return
	sprite.modulate = ore_data.tint if ore_data != null else Color.WHITE


# --- Signal callbacks ---
func _on_screen_entered() -> void:
	if not is_destroyed:
		set_collision_enabled(true)


func _on_screen_exited() -> void:
	set_collision_enabled(false)
