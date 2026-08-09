extends PanelContainer
class_name Inventory
## HUD de ores (esquina). Cascada ShellDiver: filas entran de izquierda a derecha en secuencia.

const ORE_INVENTORY_DISPLAY_SCENE = preload("uid://2pwbkmfd12eg")

@export_category("Enter Transition")
@export var play_transition_on_ready: bool = false
@export var slide_offset: float = 80.0
@export var slide_duration: float = 0.4
@export var fade_duration: float = 0.28
@export var stagger_delay: float = 0.07
@export var slide_trans: Tween.TransitionType = Tween.TRANS_QUART
@export var slide_ease: Tween.EaseType = Tween.EASE_OUT

@onready var container: VBoxContainer = %Container

## ore_id -> display activo en el HUD.
var displays: Dictionary = {}
var is_transitioning: bool = false
var transition_tweens: Array[Tween] = []


func _ready() -> void:
	EventBus.ore_amount_changed.connect(_on_ore_amount_changed)
	# Sync despues de conectar: cubre ores agregados antes de que exista este HUD.
	sync_from_currency_manager()


func _exit_tree() -> void:
	if EventBus.ore_amount_changed.is_connected(_on_ore_amount_changed):
		EventBus.ore_amount_changed.disconnect(_on_ore_amount_changed)


## Reconstruye filas desde el bag del CurrencyManager (safe si UI nace tarde).
func sync_from_currency_manager() -> void:
	var snapshot := CurrencyManager.get_ore_amounts_snapshot()
	for ore_id in snapshot.keys():
		var amount: int = int(snapshot[ore_id])
		var ore_data: OreData = CurrencyManager.get_ore_data(ore_id)
		apply_ore_amount(ore_data, ore_id, amount)
	update_panel_visibility()


## Cascada: cada fila sale de la izquierda (invisible) y aterriza en su sitio con stagger.
func do_displays_transition() -> void:
	if is_transitioning:
		return
	if container == null or container.get_child_count() == 0:
		return

	is_transitioning = true
	kill_transition_tweens()

	# Deja que el VBox termine de layout antes de cachear rests.
	await get_tree().process_frame
	if not is_inside_tree():
		is_transitioning = false
		return

	var rows: Array[Control] = []
	var rests: Array[Vector2] = []
	for child in container.get_children():
		if child is Control and is_instance_valid(child):
			rows.append(child as Control)
			rests.append((child as Control).global_position)

	if rows.is_empty():
		is_transitioning = false
		return

	# top_level: el VBox no pisa global_position durante el slide.
	for i in rows.size():
		UIJuice.prepare_slide_in_from_left(rows[i], rests[i], slide_offset)

	var preset := build_slide_preset()
	for i in rows.size():
		var row := rows[i]
		var rest := rests[i]
		var tween := UIJuice.animate_slide_in_from_left(self, row, rest, preset)
		transition_tweens.append(tween)
		if stagger_delay > 0.0 and i < rows.size() - 1:
			await get_tree().create_timer(stagger_delay).timeout

	var last_tween: Tween = transition_tweens.back() if not transition_tweens.is_empty() else null
	if last_tween != null and last_tween.is_valid() and last_tween.is_running():
		await last_tween.finished

	is_transitioning = false


func build_slide_preset() -> JuicePreset:
	var preset := JuicePreset.new()
	preset.slide_in_offset = slide_offset
	preset.slide_in_duration = slide_duration
	preset.slide_in_fade_duration = fade_duration
	preset.slide_in_trans = slide_trans
	preset.slide_in_ease = slide_ease
	preset.stagger_delay = stagger_delay
	return preset


func kill_transition_tweens() -> void:
	for tween in transition_tweens:
		if tween != null and tween.is_valid():
			tween.kill()
	transition_tweens.clear()
	# Por si se corto a mitad: devolver filas al layout.
	for child in container.get_children():
		if child is Control:
			(child as Control).top_level = false
			(child as Control).modulate.a = 1.0


## Quita instancias de editor placeholder para empezar limpio.
func clear_placeholder_displays() -> void:
	for child in container.get_children():
		child.queue_free()
	displays.clear()


## Crea o actualiza la fila. Sin OreData no se muestra icon (bag igual se conserva en manager).
func apply_ore_amount(ore_data: OreData, ore_id: String, amount: int) -> void:
	if ore_id.is_empty():
		if ore_data != null:
			ore_id = ore_data.id
		else:
			return

	if amount <= 0:
		remove_ore_display(ore_id)
		return

	if ore_data == null:
		ore_data = CurrencyManager.get_ore_data(ore_id)
	if ore_data == null:
		return

	var display := ensure_ore_display(ore_data)
	display.set_amount(amount)


func ensure_ore_display(ore_data: OreData) -> OreInventoryDisplay:
	var ore_id := ore_data.id
	if displays.has(ore_id):
		var existing: OreInventoryDisplay = displays[ore_id]
		if is_instance_valid(existing):
			return existing
		displays.erase(ore_id)

	var display: OreInventoryDisplay = ORE_INVENTORY_DISPLAY_SCENE.instantiate()
	container.add_child(display)
	displays[ore_id] = display
	display.setup(ore_data, 0)
	return display


## Asegura la fila HUD antes de que el drop vuele hacia ella.
func prepare_incoming(ore_data: OreData) -> void:
	var current := CurrencyManager.get_ore_amount(ore_data.id)
	var display := ensure_ore_display(ore_data)
	display.set_amount(maxi(current, 0))
	visible = true


## Centro del icono en coordenadas de canvas/pantalla.
func get_ore_icon_center(ore_id: String) -> Vector2:
	var display: OreInventoryDisplay = displays[ore_id]
	return display.get_icon_center()


func pulse_ore_display(ore_id: String) -> void:
	var display: OreInventoryDisplay = displays[ore_id]
	display.pulse()


func remove_ore_display(ore_id: String) -> void:
	if not displays.has(ore_id):
		return
	var display: OreInventoryDisplay = displays[ore_id]
	displays.erase(ore_id)
	display.queue_free()


func update_panel_visibility() -> void:
	visible = not displays.is_empty()


func _on_ore_amount_changed(ore_data: OreData, new_amount: int, _delta: int) -> void:
	var ore_id := ""
	if ore_data != null:
		ore_id = ore_data.id
	apply_ore_amount(ore_data, ore_id, new_amount)
	update_panel_visibility()
