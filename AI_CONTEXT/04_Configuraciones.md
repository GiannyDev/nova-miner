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
* RecapMenu → Sequence Timing en Inspector (ShellDiver minerals/title, Forager run stats/buttons, count-up). Empuja presets a los StatDisplay hijos.
* Weapons → `WeaponData` en `data/weapons/` (`drill_hit_delay`, `damage_multiplier`, `drill_spin_speed`, etc.). El player carga por `weapon_id` via `WeaponData.load_by_id()`.
* Recap → `RunRecapData` + `StatDisplay`; textos con `tr("KEY")` desde `translations/translations.csv`.
* Juice → helpers en `scripts/juice/` (`UIJuice`, `JuicePreset`); no duplicar tweens de feel en cada pantalla.

Exponer en el Inspector (`@export`, `@export_group`, `@export_subgroup`, `@export_multiline`) todo lo que un diseñador pueda querer tunear.

Todo debe ser configurable, modular y extensible.
