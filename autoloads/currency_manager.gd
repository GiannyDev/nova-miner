extends Node
## Fuente de verdad de money + inventario de ores. Emite EventBus para UI desacoplada.

const CURRENCY_DATA_PATH := "res://data/currency/currency_data.tres"

var currency_data: CurrencyData
## Runtime bag: ore_id -> cantidad. Nunca se pierde un add aunque la UI aun no exista.
var ore_amounts: Dictionary = {}


func _ready() -> void:
	load_currency_data()
	currency_data.currency_amount[CurrencyData.CurrencyType.MONEY] = 500


## Carga el .tres, indexa ores por id y deja el bag listo para pickups.
func load_currency_data() -> void:
	currency_data = load(CURRENCY_DATA_PATH) as CurrencyData
	if currency_data == null:
		push_error("CurrencyManager: no se pudo cargar %s" % CURRENCY_DATA_PATH)
		currency_data = CurrencyData.new()
	currency_data.build_ore_registry()


# --- Money (UpgradeTree) ---
func add_currency(currency_type: CurrencyData.CurrencyType, amount: int) -> void:
	currency_data.currency_amount[currency_type] = get_currency(currency_type) + amount
	EventBus.currency_ui_update.emit()


func remove_currency(currency_type: CurrencyData.CurrencyType, amount: int) -> void:
	currency_data.currency_amount[currency_type] = get_currency(currency_type) - amount
	EventBus.currency_ui_update.emit()


func get_currency(currency_type: CurrencyData.CurrencyType) -> int:
	return int(currency_data.currency_amount.get(currency_type, 0))


func can_afford(currency_type: CurrencyData.CurrencyType, amount: int) -> bool:
	return get_currency(currency_type) >= amount


## True si el bag tiene al menos `amount` del ore_id.
func can_afford_ore(ore_id: String, amount: int) -> bool:
	if ore_id.is_empty() or amount <= 0:
		return amount <= 0
	return get_ore_amount(ore_id) >= amount


## True si el bag tiene amount del Ores enum.
func can_afford_ore_type(ore: int, amount: int) -> bool:
	return can_afford_ore(Ores.get_id(ore), amount)


## Gasta ores crudos si alcanza; false si no hay suficientes.
func spend_ore(ore_id: String, amount: int) -> bool:
	if not can_afford_ore(ore_id, amount):
		return false
	remove_ore(ore_id, amount)
	return true


## Gasta usando Ores enum (dropdown de upgrades).
func spend_ore_type(ore: int, amount: int) -> bool:
	return spend_ore(Ores.get_id(ore), amount)


# --- Ore inventory ---
## Agrega amount usando la referencia OreData (id + icon). Emite evento siempre.
func add_ore(ore_data: OreData, amount: int = 1) -> void:
	if ore_data == null or ore_data.id.is_empty():
		push_error("CurrencyManager.add_ore: OreData invalido.")
		return
	if amount == 0:
		return

	var ore_id := ore_data.id
	# Preferir la instancia del catalogo para que UI siempre use la misma ref.
	var catalog_ore := get_ore_data(ore_id)
	if catalog_ore != null:
		ore_data = catalog_ore

	var new_total := get_ore_amount(ore_id) + amount
	ore_amounts[ore_id] = new_total
	EventBus.ore_amount_changed.emit(ore_data, new_total, amount)


## Agrega por id (lookup en catalogo). Si no existe OreData, solo actualiza el bag.
func add_ore_by_id(ore_id: String, amount: int = 1) -> void:
	if ore_id.is_empty() or amount == 0:
		return

	var ore_data := get_ore_data(ore_id)
	if ore_data != null:
		add_ore(ore_data, amount)
		return

	var new_total := get_ore_amount(ore_id) + amount
	ore_amounts[ore_id] = new_total
	# Sin OreData: la UI no puede crear icon; el bag igual conserva el amount.
	EventBus.ore_amount_changed.emit(null, new_total, amount)


func remove_ore(ore_id: String, amount: int = 1) -> int:
	var current := get_ore_amount(ore_id)
	var removed := mini(current, maxi(amount, 0))
	if removed <= 0:
		return 0

	var new_total := current - removed
	if new_total <= 0:
		ore_amounts.erase(ore_id)
		new_total = 0
	else:
		ore_amounts[ore_id] = new_total

	var ore_data := get_ore_data(ore_id)
	EventBus.ore_amount_changed.emit(ore_data, new_total, -removed)
	return removed


func get_ore_amount(ore_id: String) -> int:
	return int(ore_amounts.get(ore_id, 0))


func get_ore_data(ore_id: String) -> OreData:
	if currency_data == null:
		return null
	return currency_data.get_ore(ore_id)


func has_ore_data(ore_id: String) -> bool:
	return currency_data != null and currency_data.has_ore(ore_id)


## Snapshot para sync de UI (id -> amount) sin exponer el dict mutable.
func get_ore_amounts_snapshot() -> Dictionary:
	return ore_amounts.duplicate()
