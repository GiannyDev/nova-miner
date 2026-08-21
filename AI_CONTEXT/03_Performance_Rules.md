# Performance (Godot)

> **Cursor:** Este archivo es contexto obligatorio del proyecto. En cada chat nuevo, el asistente debe leer todos los `.md` en `AI_CONTEXT/` antes de proponer o escribir código. Ver `.cursor/rules/ai-context.mdc`.

**Performance is the default priority.**

## Loading & scene flow

* Use Autoload `Transition.change_scene_async(path, prepare)`:
  1. Fade out (shader cover)
  2. `change_scene_to_packed` + settle frames
  3. Fade in

## Runtime rules

* Profile early (`Debugger` → Profiler / Monitors). Optimize only after measuring.
* Object pooling where useful (Ores spawning while moving thought the map)
* Avoid work every frame in `_process` / `_physics_process` when a tick, signal, or timer is enough.
* Cache node refs with `@onready` or in `_ready` — never `get_node` in hot loops.
* Prefer `distance_squared_to` over `distance_to`.
* Avoid allocating Arrays/Dictionaries/Strings every frame.
* Keep draw calls / unique materials reasonable; reuse atlases where possible.

## Mine chunk (hot path actual)

* `MineChunk` es la ventana de spawn en celdas (`chunk_size_cells`) que viaja con el player. Su `_physics_process` sale temprano hasta que el player cruza `refresh_step_cells` (dead-zone), y se adelanta con `lookahead_cells` para que los spawns futuros queden dentro de la ventana.
* El chunk **no** decide el contenido: solo acota WHERE. `OreSpawner` genera cada celda **una vez** al revelar la ventana (`UNKNOWN` → `DIRT`/`ORE`/`MINED`). `STARTING_ORE_AMOUNT` es densidad % de mineral suelto (el resto es tierra). Clusters de mapa salen del `MineSpawnProfile`. Extras al destruir (`SPAWN_ON_DESTROY_*`, `SPAWN_CLUSTER_*`) solo pisan celdas `UNKNOWN` (anillo fuera de ventana), nunca el túnel.
* `OreSpawner` encola visuales y respeta `max_spawns_per_frame`. `on_window_moved` → cull fuera de ventana + generar Unknown + respawn visual de dirt/ore. Sin refill ni ban de celdas. Pop-in solo en intro (`intro_spawn_mode`).
* Los `Ore` se reciclan por `OrePool` con `on_spawned` / `on_despawned` (nodos huerfanos fuera del arbol). Nunca `queue_free` en un ore.
* `MineGrid` es espacio de celdas infinito (`floori`/`round`, celdas negativas validas) y solo redibuja cuando cambia el rango visible o el zoom. Pintar celdas ocupadas/reservadas es debug (`show_cell_states`): recorre los diccionarios completos.
* Ventana 21×20 ≈ 400 bloques vivos (tierra + mineral). `OrePool.prewarm_count` 480. Si el frame baja, activar `cull_collision_offscreen` en `ore.tscn` (ojo: un taladro fuera de pantalla tampoco golpea).

## Agent / coding contract

1. Before adding systems, ask: does this run every frame? allocate? scan the tree?
2. Update this doc when a new hot path or load contract lands.
