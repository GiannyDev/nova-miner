# Game Loop

> **Cursor:** Este archivo es contexto obligatorio del proyecto. En cada chat nuevo, el asistente debe leer todos los `.md` en `AI_CONTEXT/` antes de proponer o escribir código. Ver `.cursor/rules/ai-context.mdc`.

El juego es muy simple, el player entra a minas, mina ores por X segundos y regres a la base, usa o transforma los ores para progresar y comprar cosas, regresa a minar, repetir.

- El juego cuenta con 4 mapas, cada uno con 3 subminas, el user desbloquea la siguiente mina cuando completa su quota de extracción.
- El User sube de nivel cuando compra mejoras en el UpgradeTree y desbloquea cosas (Configurable el XP que da cualquier mejora del juego)
- El User gasta ores para comprar mejoras en el UpgradeTree, WeaponShop y CompanionWorkshop
- El User puede transformar ores para obtener otros recursos necesarios del juego
- Cada mapa tiene sus propios ores a spawnear segun un % a definir (Configurable en sus Resources)
- El UpgradeTree permitira comprar mejoras como PlayerSpeed, UnlockPlayerDash, PlayerDashSpeed, OreCount, SpawnXOresWhenOneDestroyed, etc. Todo para progreso del juego.
