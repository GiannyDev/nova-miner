extends Resource
class_name CurrencyData
## Catalogo de ores/monedas del juego. Los amounts runtime viven en CurrencyManager.

enum CurrencyType {
	MONEY
}

@export_group("Ore Catalog")
## Todos los OreData del juego. CurrencyManager los indexa por id al boot.
@export var currencies: Array[OreData] = []

var currency_amount: Dictionary = {
	CurrencyType.MONEY: 0
}

## Runtime: id -> OreData. Se construye en build_ore_registry().
var ores_by_id: Dictionary = {}

## Indexa currencies por id. Ignora nulls / ids vacios; avisa si hay duplicados.
func build_ore_registry() -> void:
	ores_by_id.clear()
	for ore in currencies:
		if ore == null:
			continue
		if ore.id.is_empty():
			push_warning("CurrencyData: OreData sin id, se ignora.")
			continue
		if ores_by_id.has(ore.id):
			push_warning("CurrencyData: id duplicado '%s', se sobrescribe." % ore.id)
		ores_by_id[ore.id] = ore


func get_ore(ore_id: String) -> OreData:
	return ores_by_id.get(ore_id) as OreData


func has_ore(ore_id: String) -> bool:
	return ores_by_id.has(ore_id)


func get_catalog_ores() -> Array[OreData]:
	var result: Array[OreData] = []
	for ore in currencies:
		if ore != null and not ore.id.is_empty():
			result.append(ore)
	return result
