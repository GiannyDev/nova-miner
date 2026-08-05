extends Resource
class_name RunRecapData
## Snapshot de una run de mina para el RecapMenu: minerales de la submina + stats de sesion.

@export var recap_ore_ids: Array[String] = ["gold", "silver", "platinum"]
@export var ores_collected: Dictionary = {}
@export var blocks_mined: int = 0
@export var damage_dealt: float = 0.0
@export var distance_traveled: float = 0.0


func get_ore_amount(ore_id: String) -> int:
	return int(ores_collected.get(ore_id, 0))
