# Game Pillars

> **Cursor:** Este archivo es contexto obligatorio del proyecto. En cada chat nuevo, el asistente debe leer todos los `.md` en `AI_CONTEXT/` antes de proponer o escribir código. Ver `.cursor/rules/ai-context.mdc`.

1. **Performance first (Godot)** — stable frame budget, profile-guided opts. See `03_Performance_Rules.md`.
2. "Infinite mines" que permiten al player moverse indefinidamente en cualquier direccion mientras ores se spawnean en un radio cerca a el pensando en optimizacion.
3. Beautiful Game Feel on player and robot movement, gun usage and ores spawning
4. Clean code where everything feels easy to read and understand  See `Godot_Main_Guideline`
5. Resource first aprroach where everything is maintainable. See `Godot_Main_Guideline`
6. Sistema de Spawner basado en chunks para solo spawnear ores dentro del main_chunk que siempre sigue al player