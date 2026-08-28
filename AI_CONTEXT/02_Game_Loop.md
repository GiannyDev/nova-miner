# Game Loop

> **Cursor:** Este archivo es contexto obligatorio del proyecto. En cada chat nuevo, el asistente debe leer todos los `.md` en `AI_CONTEXT/` antes de proponer o escribir código. Ver `.cursor/rules/ai-context.mdc`.

El juego es muy simple, el player entra a minas, mina ores por X segundos y regres a la base, usa o transforma los ores para progresar y comprar cosas, regresa a minar, repetir.

- El juego cuenta con 4 mapas, cada uno con 3 subminas, el user desbloquea la siguiente mina cuando completa su quota de extracción.
- El User sube de nivel cuando compra mejoras en el UpgradeTree y desbloquea cosas (Configurable el XP que da cualquier mejora del juego)
- El User gasta ores para comprar mejoras en el UpgradeTree, WeaponShop y CompanionWorkshop
- El User puede transformar ores para obtener otros recursos necesarios del juego
- Cada mapa tiene sus propios ores a spawnear segun un % a definir (Configurable en sus Resources)
- La cueva se genera al revelar celdas (`MineSpawnProfile`). Tierra + mineral + **rutas caminables** (huecos / gusanos tipo Lague). Densidad de mineral suelto = `Stats.STARTING_ORE_AMOUNT` (%). Lo minado queda hueco.
- El UpgradeTree permitira comprar mejoras como PlayerSpeed, OreCount, SpawnXOresWhenOneDestroyed, **bomb blocks** (chance / damage / radius / HP), **helpers** (count / speed / damage; sin unlock — unlock es solo para locaciones), etc.
- Ayudantes: N mineros persistentes por run (`Stats.HELPERS_UNLOCKED`). Mismo loop que el player (`MinerBody` + `DrillWeapon` + `MovementComponent`): vagan y perforan al contacto (oneshot o chip). Fuera de ventana, `mine_cell` en la celda del tip. `ensure_generated` abre túnel. Loot al bag. Iconos de borde (`OffscreenMarkerLayer`) para helpers y perks del mundo.
