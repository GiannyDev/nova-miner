class_name Ores
## Registro central de ores / moneda de upgrades.
## Uso: Ores.GOLD, Ores.SILVER, etc. (igual que Stats).

enum {
	GOLD,
	SILVER,
	PLATINUM,
}


## Id de catalogo / bag (CurrencyManager, OreData.id).
static func get_id(ore: int) -> String:
	match ore:
		Ores.GOLD:
			return "gold"
		Ores.SILVER:
			return "silver"
		Ores.PLATINUM:
			return "platinum"
		_:
			return "unknown_%d" % int(ore)


## Todos los ores conocidos (para save / iteracion).
static func all_ids() -> Array[int]:
	return [GOLD, SILVER, PLATINUM]


## Parsea string de catalogo a enum. -1 si no existe.
static func from_id(ore_id: String) -> int:
	match ore_id:
		"gold":
			return Ores.GOLD
		"silver":
			return Ores.SILVER
		"platinum":
			return Ores.PLATINUM
		_:
			return -1
