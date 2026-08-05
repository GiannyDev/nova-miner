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
* El chunk **no** genera ores al moverse: solo acota WHERE puede spawnear el `OreSpawner`. Los ores aparecen al entrar (`starting_ore_amount` × `ore_density_mult`) y al destruir bloques segun stats del UpgradeTree (`spawn_on_destroy_chance`, `spawn_extra_on_destroy`, `destroy_cluster_chance`, etc.).
* `OreSpawner` separa elegir celdas (aritmetica + diccionario) de instanciar: encola y respeta `max_spawns_per_frame`. Su `_process` se apaga solo cuando la cola queda vacia.
* Los `Ore` se reciclan por `OrePool` con `on_spawned` / `on_despawned` (nodos huerfanos fuera del arbol). Nunca `queue_free` en un ore.
* `MineGrid` es espacio de celdas infinito (`floori`/`round`, celdas negativas validas) y solo redibuja cuando cambia el rango visible o el zoom. Pintar celdas ocupadas/reservadas es debug (`show_cell_states`): recorre los diccionarios completos.
* Medido en 4.7 con 21x20 celdas y densidad 0.52: ~2000 ores / ~9900 nodos a 180 FPS. Si el conteo sube, activar `cull_collision_offscreen` en `ore.tscn` (ojo: un taladro fuera de pantalla tampoco golpea).

## Agent / coding contract

1. Before adding systems, ask: does this run every frame? allocate? scan the tree?
2. Update this doc when a new hot path or load contract lands.
