extends PanelContainer
class_name Inventory
## HUD de ores: crea/actualiza OreInventoryDisplay por eventos. Sync al ready por si hay pickups previos.

const ORE_INVENTORY_DISPLAY_SCENE = preload("uid://2pwbkmfd12eg")

# --- Onready / cached ---
@onready var container: VBoxContainer = %Container

# --- Runtime ---
## ore_id -> display activo en el HUD.
var displays: Dictionary = {}


# --- Built-ins ---
func _ready() -> void:
	clear_placeholder_displays()
	EventBus.ore_amount_changed.connect(_on_ore_amount_changed)
	# Sync despues de conectar: cubre ores agregados antes de que exista este HUD.
	sync_from_currency_manager()
	update_panel_visibility()


func _exit_tree() -> void:
	if EventBus.ore_amount_changed.is_connected(_on_ore_amount_changed):
		EventBus.ore_amount_changed.disconnect(_on_ore_amount_changed)


# --- Public API ---
## Reconstruye filas desde el bag del CurrencyManager (safe si UI nace tarde).
func sync_from_currency_manager() -> void:
	var snapshot := CurrencyManager.get_ore_amounts_snapshot()
	for ore_id in snapshot.keys():
		var amount: int = int(snapshot[ore_id])
		var ore_data: OreData = CurrencyManager.get_ore_data(ore_id)
		apply_ore_amount(ore_data, ore_id, amount)
	update_panel_visibility()


# --- Private helpers (no leading _) ---
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


func remove_ore_display(ore_id: String) -> void:
	if not displays.has(ore_id):
		return
	var display: OreInventoryDisplay = displays[ore_id]
	displays.erase(ore_id)
	if is_instance_valid(display):
		display.queue_free()


func update_panel_visibility() -> void:
	visible = not displays.is_empty()


# --- Signal callbacks ---
func _on_ore_amount_changed(ore_data: OreData, new_amount: int, _delta: int) -> void:
	var ore_id := ""
	if ore_data != null:
		ore_id = ore_data.id
	apply_ore_amount(ore_data, ore_id, new_amount)
	update_panel_visibility()
