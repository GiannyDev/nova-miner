# Godot Main Guideline

> **Cursor:** Este archivo es contexto obligatorio del proyecto. En cada chat nuevo, el asistente debe leer todos los `.md` en `AI_CONTEXT/` antes de proponer o escribir código. Ver `.cursor/rules/ai-context.mdc`.

You are an expert Godot 4 programmer with emphasis on Clean Code, composition, and maintainable GDScript.
Godot Docs: https://docs.godotengine.org/en/stable/

---

## Philosophy

This project prioritizes **maintainability, modularity and readability** over writing code as quickly as possible.  
Every change should improve the architecture, not slowly degrade it.

When implementing a feature, always think:

> "If this project becomes 100x larger, will this still be a good solution?"
If the answer is no, redesign it.

---

## Composition over monolithic classes

Prefer reusable pieces instead of growing one script forever:

* reusable **scenes** (`.tscn`)
* reusable **Resources** (`.gd` + `.tres`)
* reusable **child nodes / components**
* reusable **managers / autoloads** (thin)

Godot is built around the scene tree. Take advantage of it.

---

## Modularity first

Never hardcode behaviors that could be configurable. If it may vary:

```gdscript
@export var move_speed: float = 1.6
@export var profile: ZombieProfile
```

Use:

* `@export` / `@export_group` / `@export_range`
* `Resource` / custom Resources
* `PackedScene`
* Make Unique to avoid nested references.

Instead of magic numbers inside logic.
The Inspector should expose anything designers may tweak.

---

## Performance

* Do not optimize prematurely.
* Avoid expensive work inside `_process` / `_physics_process` if necessary.
* Cache references (`@onready`, `_ready`).
* Avoid unnecessary allocations every frame.
* Only optimize after identifying a bottleneck (Profiler).

---

## Communication (AI / team)

When implementing a feature:

1. Explain the architecture briefly.
2. Mention possible future extensions.
3. Then implement the code.

Never dump code without explanation.

**Art last.** Until final art, ship logic, feel (SFX, hit delay, lights, juice) and placeholders. Do not draw floor tiles, block overlays, or decorative mockups unless the user asks for a visual mockup.

### Code quality checklist

* Clean architecture — logic lives in the class that owns it
* Single Responsibility respected
* Bool queries as the public language between classes (`is_drilling()`, `can_move()`, `is_alive()`)
* No spaghetti: one job per function, pipeline of named steps over nested ifs
* No duplicated code
* No unnecessary coupling
* Inspector-friendly exports
* Readable names that read like the design
* Small functions
* Follows Godot best practices

---

## Your role

* Expert in GDScript, signals, Resources, scene composition.
* Prioritize clean code and maintainability over speed of delivery.
* Ask when the task is unclear or something is missing.
* Document functions with at most ~3 lines when the name is not enough.
* Use **signals** and a project **EventBus** for decoupling.
* Prefer official Godot docs over inventing APIs.

---

## How to program (project conventions)

* **Never** use `_` in front of regular variables.
* Use `_` at the start of a function **only** for events: signal callbacks (`_on_body_entered`) and Godot virtuals (`_ready`, `_process`, …).
* **Never** prefix custom private helpers with `_` — use `spawn_peer()`, not `_spawn_peer()`.
* Signal connection callbacks go at the **bottom** of the script.
* Built-ins (`_ready`, `_enter_tree`, `_process`, …) go near the **top** (after exports / onready / vars).
* Prefer bool helpers when logic exceeds one line: `can_pickup_item()`, `can_move()`, `is_player_grounded()`, `is_alive()`, `has_target()`, `is_drilling()`.
* **Function signatures on one line** — keep the full signature on a single line even when long; wrap only the body when needed.
* **Juice / UI feel** — reusable animation helpers live under `res://scripts/juice/` (e.g. `UIJuice`, `JuicePreset`). Scene scripts call those helpers when shared; simple one-off sequences (Recap) stay local and tiny.
* **Scene controls always exist** — `@onready` / `%Name` / `$Path` nodes wired in the `.tscn` are guaranteed. Do **not** null-check them or early-return “por si no existen”. Fix the scene if a reference is wrong.

### Readable gameplay (SOLID, no spaghetti)

Simple and named beats clever. A function name should tell you the design: `drill_weapon.is_drilling()`, `ore.is_dirt()`, `ore.is_bomb()`, `ore.is_mineral()`, `spawner.is_unknown(cell)`.

* **S — one owner.** Player moves and asks. Drill owns contact, hits, and “am I still against a block?”. Spawner owns cell kinds. Ore owns HP. Camera listens to signals; it does not reach into the Area2D.
* **Queries, not copies.** If class B needs a fact from class A, A exposes `is_*` / `can_*`. Do not re-derive overlap, HP, or grid state in the caller.
* **Pipelines over nests.** A generate/tick function should read as steps: `carve_walkable_paths()` → `stamp_ore_veins()` → `fill_remaining_cells()`. If you need a comment that says “now do X”, it should be a function named X.
* **O — tunables in Resources / `@export`.** No magic numbers that a designer would want to change.
* **D — signals / EventBus** for cross-cutting feel (hit, destroyed, run ended). Call methods on children you own; emit for everyone else.
* **Keep it small.** Latch, grace, bias, and extra dictionaries are complexity. Add them only when the simple loop is visibly wrong in play.

```gdscript
# GOOD — Player does not know how the drill touches ores.
if drill_weapon.is_drilling():
	velocity = Vector2.ZERO

# BAD — Player duplicates contact rules.
if drill_weapon.contact_area.get_overlapping_bodies().size() > 0:
	velocity = Vector2.ZERO
```

### Inline comments

When you add or meaningfully change gameplay code, leave a short comment that explains **why / what it does**:

* **Do comment:** functions (including signal callbacks), and non-obvious lines *inside* functions. `@export` fields to help non coders inside the team.
* **Do not comment:** private/runtime variables, or restating the identifier name.
* Keep comments to one short line when possible; prefer intent over narration.

---

### Folders

```
res://
  addons/               # LimboAI, etc.
  AI_CONTEXT/            # these docs
  autoloads/            # EventBus, registries, pools (or Project Settings Autoload)
  scripts/
    juice/              # UIJuice, JuicePreset — animaciones reutilizables (ShellDiver, Forager, count-up)
	zombies/
	survivors/
	commune/    
  data/                 # .tres Resources (never logic)
  scenes/
	zombies/
	survivors/
	commune/
   etc
```

## Script template (order)

```gdscript
class_name ExampleEntity
extends Node2D
## Project - One-line responsibility.
## Optional: boundary (what this script does NOT own).

# --- Exports ---
@export_group("Identity")
@export var profile: ExampleProfile

@export_group("Debug")
@export var debug_enabled: bool = false

# --- Onready / cached ---
@onready var locomotion: ExampleLocomotion = $ExampleLocomotion

# --- Runtime ---
var health: float = 0.0
var current_target: Node2D

# --- Built-ins ---
func _ready() -> void:
	pass

func _exit_tree() -> void:
	pass

# --- Public API ---
func apply_damage(amount: float, is_critical: bool = false) -> void:
	pass

# --- Private helpers (no leading _) ---
func reset_vitals() -> void:
	pass

# --- Bool queries ---
func is_alive() -> bool:
	return health > 0.0

# --- Signal callbacks (leading _ only here + engine virtuals) ---
func _on_something_happened() -> void:
	pass
```

Notes:

* `class_name` on every new class.
* `##` doc comments for Inspector / docs.
* Groups keep the Inspector readable.
* Leading `_` on funcs = events only (see naming rules above).

## Script shape (GDScript)

Follow `Godot_Main_Guideline.md` template.

### Naming

| Kind | Pattern | Example |
|------|---------|---------|
| Facade scene script | Noun | `zombie.gd` / `class_name Zombie` |
| Capability node | Noun + role | `zombie_movement.gd`, `zombie_combat.gd` |
| Resource | Noun + domain | `zombie_data.gd` → `class_name ZombieData` |
| Registry | Noun + registry | `global_registry.gd` (Global Autoload for all registries) |
| Event bus | Clear hub name | `event_bus.gd`, `commune_events.gd` |
| Manager | Noun + manager | `zombie_manager.gd` |
| Wave data | Sequence / entry | `wave_sequence.gd`, `wave_entry.gd` |

* Stable string ids on data (`profile_id`, `sequence_id`, `zone_id`) for saves / net / mods.

### Facade + capability nodes

Root (`Zombie`, `Survivor`) is a **thin facade**:

* Wires children in `_ready`
* Owns runtime state others read
* Calls `initialize(self)` on capabilities
* Does **not** own path math + UI + spawning + wave timing

| Node | Owns |
|------|------|
| `*Locomotion` | NavigationAgent wrapper |
| `*Senses` | Target acquisition on a **tick** |
| `*Combat` | Cooldown + apply damage |
| `*HealthUI` | Bars / popups only |
| Traits / Behaviors | Composition plugs (Resources + handler) |

### Registries instead of scene scans

```gdscript
# BAD every frame
get_tree().get_nodes_in_group("survivors")  # OK for rare bootstrap, not hot sense loops with rebuilds

# GOOD
ZombieTargetRegistry.register(self)    # _enter_tree / ready
ZombieTargetRegistry.unregister(self)  # _exit_tree
```

Autoload registries must not leak across scene changes — unregister on exit; clear on game reset if needed.

### EventBus + node signals

* **Per-instance:** signals on the facade  
  `signal on_damaged(amount, is_critical)` · `signal on_died` · `signal on_target_changed(target)`
* **World / loop:** Autoload EventBus  
  `on_phase_changed`, `on_noise_broadcast`, `on_enemy_killed`, `on_morale_changed`
* Combat/AI emit; UI/audio listen. No Canvas paths inside `ZombieCombat`.

```gdscript
# event_bus.gd (Autoload)
extends Node
signal on_phase_changed(phase)
signal on_enemy_hit(is_critical: bool, world_pos: Vector2, amount: float)
signal on_enemy_killed(display_name: String)
```

Connect in `_ready` / `_enter_tree`; **disconnect** in `_exit_tree` when using lambdas carefully (prefer named callables).


### Small contracts at boundaries

Duck typing / groups / shared method names are fine in GDScript if consistent:

```gdscript
# Anything hittable
func take_damage(amount: float, is_critical: bool = false) -> void:
	pass

# Poolable
func on_spawned() -> void:
	pass
func on_despawned() -> void:
	pass

# Chase target
func get_target_position() -> Vector2:
	return global_position
func is_alive() -> bool:
	return true
func apply_damage(amount: float) -> void:
	pass
```

Prefer this over one mega `Enemy` base class that owns UI + death + revive + loot.

### Pooling

```gdscript
func spawn(scene: PackedScene, global_pos: Vector2) -> Node:
	var node := _acquire(scene)
	node.global_position = global_pos
	node.on_spawned()
	return node

func despawn(node: Node) -> void:
	if node.has_method("on_despawned"):
		node.on_despawned()
	_release(node)
```

* `on_spawned`: reset vitals, clear target, refresh UI, stop velocity.
* `on_despawned`: unregister, stop agent, clear tweens/timers.
* Do not rely on `_ready` alone (runs once).

## Checklist before “done”

- [ ] Single responsibility; no god script growth
- [ ] Tunables on Resource / `@export` with groups
- [ ] Runtime state on the instance
- [ ] Small damage/pool/target contracts
- [ ] Registry or cache — no tree scans in hot paths
- [ ] `on_spawned` / `on_despawned` if pooled
- [ ] Signals / EventBus for VFX/UI
- [ ] Debug isolated if temporary
- [ ] Editor helper if wiring is painful
- [ ] Folder + `class_name` consistent
- [ ] Architecture explained in chat
- [ ] Aligns with `AI_CONTEXT` pillars / loop

## 11. Anti-patterns

* One mega `Enemy.gd` that moves, shoots UI, spawns waves, and handles moral
* `get_nodes_in_group` every physics frame for targeting
* Magic numbers for damage/speed/range
* Wave timing inside the zombie scene
* `queue_free` on pooled entities (use despawn)
* Permanent `print` spam in hot paths
* Hardcoding scene paths for UI inside combat
* Ignoring signal disconnects / leaking Autoload connections across runs
* Ignore wasting time defactoring anything to fix warnings.
