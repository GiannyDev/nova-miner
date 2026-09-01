# Game Pillars

> **Cursor:** Este archivo es contexto obligatorio del proyecto. En cada chat nuevo, el asistente debe leer todos los `.md` en `AI_CONTEXT/` antes de proponer o escribir código. Ver `.cursor/rules/ai-context.mdc`.

1. **Performance first (Godot)** — stable frame budget, profile-guided opts. See `03_Performance_Rules.md`.
2. "Infinite mines" generate-once: el player se mueve en cualquier dirección; la ventana del chunk revela celdas nuevas (tierra u ore). Lo minado queda hueco. Visuales se reciclan fuera de ventana; el kind persiste.
3. Beautiful Game Feel on player and robot movement, gun usage and ores spawning. **Logica y feel primero; arte al final.** No inventar piso, bloques, HUD ni mockups visuales extra salvo que se pida explicitamente un mockup.
4. Clean code where everything feels easy to read and understand  See `Godot_Main_Guideline`
5. Resource first aprroach where everything is maintainable. See `Godot_Main_Guideline`
6. Sistema de Spawner basado en chunks para solo spawnear ores dentro del main_chunk que siempre sigue al player