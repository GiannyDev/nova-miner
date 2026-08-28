extends Node

signal upgrade_purchased(upgrade_id: String, upgrade_type: int, new_level: int)
signal upgrade_stat_changed(stat_id: int, new_value: float)
signal currency_ui_update

## ore_data puede ser null si el id no esta en el catalogo; new_amount es el total post-cambio.
signal ore_amount_changed(ore_data: OreData, new_amount: int, delta: int)

signal on_level_floor_selected(floor: LevelData)

signal on_run_started
signal on_run_ended
signal run_ore_destroyed(ore: Ore)
## Minado logico (ayudante fuera de ventana). ore_data puede ser dirt/bomb/mineral.
signal cell_mined(ore_data: OreData)

## Durabilidad de la perforadora (HUD + fin de run).
signal drill_durability_changed(current: float, max_value: float)
signal drill_durability_depleted

## Tooltip de perk en mina (hover display).
signal on_perk_mine_display_tooltip(display: PerkMineDisplay)
signal on_perk_mine_display_tooltip_hide
