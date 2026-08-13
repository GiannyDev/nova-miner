extends HBoxContainer
class_name OreInventoryDisplay
## Fila del HUD: icono + amount de un OreData concreto.

# --- Onready / cached ---
@onready var ore_icon: TextureRect = $OreIcon
@onready var ore_amount_label: Label = $OreAmountLabel

# --- Runtime ---
var ore_data: OreData
var ore_id: String = ""
var pending_amount: int = 0


# --- Built-ins ---
func _ready() -> void:
	refresh_visuals()
	ore_amount_label.text = str(maxi(pending_amount, 0))


# --- Public API ---
## Bind al OreData del catalogo. Seguro llamar antes o despues de entrar al arbol.
func setup(data: OreData, amount: int) -> void:
	ore_data = data
	if ore_data != null:
		ore_id = ore_data.id
	pending_amount = amount
	if is_node_ready():
		refresh_visuals()
		set_amount(amount)


func set_amount(amount: int) -> void:
	pending_amount = amount
	if not is_node_ready():
		return
	ore_amount_label.text = str(maxi(amount, 0))


## Centro global del icono (para homing de OreDrop).
func get_icon_center() -> Vector2:
	return ore_icon.get_global_rect().get_center()


## Pop breve al recibir un drop.
func pulse() -> void:
	ore_icon.pivot_offset = ore_icon.size * 0.5
	Springer.scale(ore_icon, 0.2, 1.0)


func refresh_visuals() -> void:
	if not is_node_ready():
		return
	if ore_data != null and ore_data.currency_sprite != null:
		ore_icon.texture = ore_data.currency_sprite
	ore_icon.modulate = Color(1.15, 1.08, 0.75) if ore_data != null and ore_data.is_refined else Color.WHITE
