extends Node

signal upgrade_purchased
signal currency_ui_update

## ore_data puede ser null si el id no esta en el catalogo; new_amount es el total post-cambio.
signal ore_amount_changed(ore_data: OreData, new_amount: int, delta: int)

signal on_level_floor_selected(floor: LevelData)

signal on_run_started
signal on_run_ended
signal run_ore_destroyed(ore: Ore)
