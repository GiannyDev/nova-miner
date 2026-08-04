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

## Agent / coding contract

1. Before adding systems, ask: does this run every frame? allocate? scan the tree?
2. Update this doc when a new hot path or load contract lands.
