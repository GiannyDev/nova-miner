class_name Ores
## Registro central de ores / moneda de upgrades.
## Uso: Ores.GOLD, Ores.GOLD_REFINED, etc. (igual que Stats).

enum {
	GOLD,
	SILVER,
	PLATINUM,
	GOLD_REFINED,
	SILVER_REFINED,
	PLATINUM_REFINED,
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
		Ores.GOLD_REFINED:
			return "gold_refined"
		Ores.SILVER_REFINED:
			return "silver_refined"
		Ores.PLATINUM_REFINED:
			return "platinum_refined"
		_:
			return "unknown_%d" % int(ore)


## Todos los ores conocidos (para save / iteracion).
static func all_ids() -> Array[int]:
	return [GOLD, SILVER, PLATINUM, GOLD_REFINED, SILVER_REFINED, PLATINUM_REFINED]


## Parsea string de catalogo a enum. -1 si no existe.
static func from_id(ore_id: String) -> int:
	match ore_id:
		"gold":
			return Ores.GOLD
		"silver":
			return Ores.SILVER
		"platinum":
			return Ores.PLATINUM
		"gold_refined":
			return Ores.GOLD_REFINED
		"silver_refined":
			return Ores.SILVER_REFINED
		"platinum_refined":
			return Ores.PLATINUM_REFINED
		_:
			return -1


static func is_refined_enum(ore: int) -> bool:
	return ore == GOLD_REFINED or ore == SILVER_REFINED or ore == PLATINUM_REFINED
