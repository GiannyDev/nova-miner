# Configuraciones

> **Cursor:** Este archivo es contexto obligatorio del proyecto. En cada chat nuevo, el asistente debe leer todos los `.md` en `AI_CONTEXT/` antes de proponer o escribir código. Ver `.cursor/rules/ai-context.mdc`.

El juego busca iteraciones rápidas para probar y modificar valores.
Nuestros proyectos siempre tiene Godot MCP enabled, usalo cuando aplicas algo importante para verificar funcionalidad o fallos.

**Todo sistema debe ser ultra configurable con Resources (Custom Resources).**

* Items → `Resource` con tipo, id, icono, etc.
* Ores → `Resource` con texture, name, etc.
* SubMine → `Resource` con icon, name, ore, ore_chance, quota, etc.
* Maps → `Resource` con array[submine], name, banner, etc.
* UpgradeTree → cada `UpgradeNode` lleva un `StatUpgrade` con `id` unico (save + stat), `costs[]` y `values[]` paralelos. Reveal ShellDiver: cascada BFS (linea crece → nodo pop), timings en categoria Reveal Animation.
* RecapMenu → secuencia simple en Inspector (`Sequence`): paneles juntos sin texto → delay → textos en cadena (stagger) → delay → `records_panel`. Sin presets ShellDiver/Forager en el recap.
* SaveData → `user://nova_miner_save.json` (upgrades, stats, records). Antes de sobrescribir copia a `nova_miner_save.bak.json`. Si el save principal falla al cargar, usa el backup. Records: blocks / damage / distance; el Recap aplica y muestra `NEW` si se rompe la marca.
* Weapons → `WeaponData` en `data/weapons/` (`drill_hit_delay`, `damage_multiplier`, `drill_spin_speed`, etc.). El player carga por `weapon_id` via `WeaponData.load_by_id()`.
* Recap → `RunRecapData` + `StatDisplay`; textos con `tr("KEY")` desde `translations/translations.csv`.
* DamageText → `scenes/ui/damage_text/`; spawn via `Feedbacks.spawn_damage_text(amount, world_pos, mine_dir)` (pop gordo → stretch en direccion de minado).
* OreDrop → cae/rebota y vuela en curva (`Feedbacks.do_jump`) al icono de `Inventory` (`Refs.inventory`).
* Mine intro → `GameStates.INTRO`: player delay → ores `play_rise_animation` todos a la vez → `begin_run()` (`PLAYING` + `on_run_started`). Timings en MineZone `Intro`.
* Juice → helpers en `scripts/juice/` (`UIJuice`, `JuicePreset`) donde aporten; no forzar presets en pantallas que ya tienen una secuencia propia simple.

Exponer en el Inspector (`@export`, `@export_group`, `@export_subgroup`, `@export_multiline`) todo lo que un diseñador pueda querer tunear.

Todo debe ser configurable, modular y extensible.

## Controles de escena siempre existen

Los nodos cableados en `.tscn` (`@onready`, `%UniqueName`, paths `$Child`) **siempre existen** en runtime. No hagas `if node != null` / early-return defensivos por si “faltara” un control de UI o gameplay de la escena. Si falta, es un error de escena que debe romperse claro — no enmascararlo con checks.