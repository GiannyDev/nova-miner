extends Node2D
class_name MineZone
## Zona de mina: cablea grid, chunk, spawner, pool, player. Fin de run = durabilidad 0.

const PERK_DISPLAY_SCENE := preload("res://scenes/ui/perks/perk_mine_display.tscn")

@export var recap_ore_ids: Array[String] = ["gold", "silver", "platinum"]

@export_category("Perks")
@export var debug_start_perks: Array[PerkData] = []
@export var perk_tooltip_spring: float = 8.0

@export_category("Intro")
@export var player_intro_delay: float = 0.4
@export var delay_before_ores_rise: float = 0.15
@export var ores_rise_duration: float = 0.55

@export_category("Debug")
@export var debug_fast_forward: float = 1.0

@onready var grid: MineGrid = $MineGrid
@onready var chunk: MineChunk = $MineChunk
@onready var ore_pool: OrePool = $OrePool
@onready var ore_spawner: OreSpawner = $OreSpawner
@onready var ysort: Node2D = $YSort
@onready var player: Player = $YSort/Player

## GUI
@onready var inventory: Inventory = %Inventory
@onready var drill_durability: ProgressBar = %DrillDurability
@onready var durability_title: Label = %DurabilityTitle
@onready var durability_value: Label = %DurabilityValue
@onready var recap_menu: RecapMenu = %RecapMenu
@onready var settings_menu: SettingsMenu = %SettingsMenu

## Perk Tooltip
@onready var perks_tooltip: PanelContainer = %PerksTooltip
@onready var perks_container: VBoxContainer = %PerksContainer
@onready var perk_title: Label = %PerkTitle
@onready var perk_description: Label = %PerkDescription
@onready var perk_value: Label = %PerkValue

var durability_init_pos := Vector2(460, 1014)
var durability_final_pos := Vector2(460, 1142)

var perks: Array[PerkMineDisplay] = []

var ores_collected: Dictionary = {}
var blocks_mined: int = 0
var damage_dealt: float = 0.0
var distance_traveled: float = 0.0
var last_player_cell: Vector2i = Vector2i.ZERO
var run_elapsed: float = 0.0
var run_ended: bool = false


func _ready() -> void:
	GameManager.curr_state = GameManager.GameStates.INTRO
	run_ended = false
	run_elapsed = 0.0
	Refs.inventory = inventory
	Refs.mine_zone = self
	ore_spawner.setup(grid, chunk, ysort, ore_pool)
	GameManager.repair_drill_full()
	spawn_player()
	connect_run_tracking()
	connect_perk_tooltip()
	setup_durability_hud()
	hide_perk_tooltip()
	setup_debug_perks()
	await play_intro_sequence()
	begin_run()


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("fast_forward"):
		Engine.time_scale = debug_fast_forward
	elif event.is_action_released("fast_forward"):
		Engine.time_scale = 1.0


func _physics_process(delta: float) -> void:
	if run_ended or GameManager.curr_state != GameManager.GameStates.PLAYING:
		return
	run_elapsed += delta
	track_distance_traveled()


func _process(delta: float) -> void:
	if run_ended or GameManager.curr_state != GameManager.GameStates.PLAYING:
		return
	GameManager.consume_drill_durability(delta)
	refresh_durability_hud()


func connect_run_tracking() -> void:
	if not EventBus.ore_amount_changed.is_connected(_on_ore_amount_changed): EventBus.ore_amount_changed.connect(_on_ore_amount_changed)
	if not EventBus.run_ore_destroyed.is_connected(_on_run_ore_destroyed): EventBus.run_ore_destroyed.connect(_on_run_ore_destroyed)
	if not EventBus.drill_durability_depleted.is_connected(_on_drill_durability_depleted): EventBus.drill_durability_depleted.connect(_on_drill_durability_depleted)
	if not EventBus.drill_durability_changed.is_connected(_on_drill_durability_changed): EventBus.drill_durability_changed.connect(_on_drill_durability_changed)
	if player != null and not player.dealt_damage.is_connected(_on_dealt_damage): player.dealt_damage.connect(_on_dealt_damage)


func connect_perk_tooltip() -> void:
	perks_tooltip.reset_size()
	if not EventBus.on_perk_mine_display_tooltip.is_connected(_on_perk_mine_display_tooltip):
		EventBus.on_perk_mine_display_tooltip.connect(_on_perk_mine_display_tooltip)
	if not EventBus.on_perk_mine_display_tooltip_hide.is_connected(_on_perk_mine_display_tooltip_hide):
		EventBus.on_perk_mine_display_tooltip_hide.connect(_on_perk_mine_display_tooltip_hide)


func setup_durability_hud() -> void:
	durability_title.text = "Drill Durability"
	drill_durability.max_value = 1.0
	drill_durability.min_value = 0.0
	refresh_durability_hud()


## Coloca al player en el origen (centro del mapa) y lo registra globalmente.
func spawn_player() -> void:
	player.global_position = Vector2.ZERO
	last_player_cell = grid.world_to_cell(player.global_position)
	Refs.player = player


## Intro: player (placeholder) → ores crecen todos juntos → recien ahi empieza la run.
func play_intro_sequence() -> void:
	# Placeholder hasta que exista la animacion de entrada del player.
	await get_tree().create_timer(player_intro_delay).timeout

	ore_spawner.intro_spawn_mode = true
	start_mine_generation()
	ore_spawner.flush_spawn_queue()
	ore_spawner.intro_spawn_mode = false

	await get_tree().create_timer(delay_before_ores_rise).timeout
	await ore_spawner.play_intro_rise_all(ores_rise_duration)


func begin_run() -> void:
	GameManager.curr_state = GameManager.GameStates.PLAYING
	refresh_durability_hud()
	EventBus.on_run_started.emit()


func start_mine_generation() -> void:
	ore_spawner.reserve_entry_area(player.global_position)
	chunk.follow(player)
	ore_spawner.spawn_initial_batch()


func spawn_extra_ores(cell: Vector2i, count: int) -> void:
	ore_spawner.spawn_burst_around(cell, count)


func boost_chunk_size(extra_cells: Vector2i, duration: float) -> void:
	chunk.add_size_modifier(&"skill_boost", extra_cells, duration)


## Carga perks de prueba exportados en el inspector.
func setup_debug_perks() -> void:
	clear_perks()
	for perk in debug_start_perks:
		add_perk(perk)


## Instancia un PerkMineDisplay con la data y lo mete al container.
func add_perk(data: PerkData) -> PerkMineDisplay:
	if data == null or perks_container == null:
		return null
	var display := PERK_DISPLAY_SCENE.instantiate() as PerkMineDisplay
	perks_container.add_child(display)
	display.setup(data)
	perks.append(display)
	return display


## Agrega varios perks de golpe (orden = orden en el array).
func add_perks(datas: Array[PerkData]) -> void:
	for data in datas:
		add_perk(data)


## Quita todos los displays del container.
func clear_perks() -> void:
	perks.clear()
	if perks_container == null:
		return
	for child in perks_container.get_children():
		child.queue_free()


## Tooltip: misma X, Y alineada al top del display; spring rotate.
## Posiciona con offsets (no global_position) para no estirar por anchors top-right.
func show_perk_tooltip(display: PerkMineDisplay) -> void:
	if display == null or display.perk_data == null or perks_tooltip == null:
		return
	
	var data := display.perk_data
	perk_title.text = data.title
	perk_description.text = data.description
	
	var parent_control := perks_tooltip.get_parent() as Control
	perks_tooltip.show()
	perks_tooltip.modulate.a = 0.0
	perks_tooltip.reset_size()
	await get_tree().process_frame
	if not is_instance_valid(perks_tooltip) or not is_instance_valid(display):
		return

	var height := maxf(perks_tooltip.get_combined_minimum_size().y, 1.0)
	var local_y := display.global_position.y
	if parent_control != null:
		local_y -= parent_control.global_position.y
	perks_tooltip.offset_top = local_y
	perks_tooltip.offset_bottom = local_y + height / 2
	perks_tooltip.reset_size()
	perks_tooltip.offset_bottom = perks_tooltip.offset_top + maxf(perks_tooltip.size.y, height)
	perks_tooltip.rotation_degrees = 0.0
	perks_tooltip.modulate.a = 1.0
	Springer.rotate(perks_tooltip, perk_tooltip_spring)


func hide_perk_tooltip() -> void:
	if perks_tooltip != null:
		perks_tooltip.hide()


## 1 metro por cada celda recorrida (Manhattan en el grid).
func track_distance_traveled() -> void:
	if grid == null or player == null:
		return
	var current_cell := grid.world_to_cell(player.global_position)
	if current_cell == last_player_cell:
		return
	var delta := current_cell - last_player_cell
	distance_traveled += float(absi(delta.x) + absi(delta.y))
	last_player_cell = current_cell


func build_recap_data() -> RunRecapData:
	var recap := RunRecapData.new()
	recap.recap_ore_ids = recap_ore_ids.duplicate()
	recap.ores_collected = ores_collected.duplicate()
	recap.blocks_mined = blocks_mined
	recap.damage_dealt = damage_dealt
	recap.distance_traveled = distance_traveled
	return recap


func get_time_format(seconds: float) -> String:
	var total_seconds := int(seconds)
	var minutes := int(total_seconds / 60.0)
	var secs := total_seconds % 60
	return "%02d:%02d" % [minutes, secs]


func refresh_durability_hud() -> void:
	var current: float = GameManager.get_drill_durability()
	var max_value: float = maxf(GameManager.get_drill_durability_max(), 0.001)
	var ratio := clampf(current / max_value, 0.0, 1.0)

	drill_durability.value = ratio
	durability_value.text = "%d%%" % int(round(ratio * 100.0))


func end_run() -> void:
	run_ended = true
	EventBus.on_run_ended.emit()
	GameManager.curr_state = GameManager.GameStates.PAUSED
	SaveData.save_progress()
	var tween := create_tween()
	tween.parallel().tween_property(drill_durability, "global_position", durability_final_pos, 0.25).set_ease(Tween.EASE_IN)
	tween.parallel().tween_property(perks_container, "global_position", Vector2(1950, 20), 0.25).set_ease(Tween.EASE_IN)
	tween.parallel().tween_property(inventory, "global_position", Vector2(-100, 20), 0.25).set_ease(Tween.EASE_IN)
	recap_menu.show_recap(build_recap_data())


func _on_ore_amount_changed(ore_data: OreData, _new_amount: int, delta: int) -> void:
	if delta <= 0 or GameManager.curr_state != GameManager.GameStates.PLAYING:
		return
	var ore_id := ore_data.id if ore_data != null else ""
	if ore_id.is_empty():
		return
	ores_collected[ore_id] = int(ores_collected.get(ore_id, 0)) + delta


func _on_run_ore_destroyed(ore: Ore) -> void:
	if GameManager.curr_state != GameManager.GameStates.PLAYING:
		return
	if ore != null and ore.is_dirt():
		return
	blocks_mined += 1


func _on_dealt_damage(amount: float) -> void:
	if amount <= 0.0 or GameManager.curr_state != GameManager.GameStates.PLAYING:
		return
	damage_dealt += amount


func _on_drill_durability_changed(_current: float, _max_value: float) -> void:
	refresh_durability_hud()


func _on_drill_durability_depleted() -> void:
	print("ended")
	end_run()


func _on_perk_mine_display_tooltip(display: PerkMineDisplay) -> void:
	show_perk_tooltip(display)


func _on_perk_mine_display_tooltip_hide() -> void:
	hide_perk_tooltip()
