# Deep Space Miner — Referencia Técnica

> Documento de referencia para futuros chats. Describe la lógica completa del juego en `REFERENCIA/Deep Space Miner/` con rutas de clases para consulta rápida.

**Ruta local:** `REFERENCIA/Deep Space Miner/`  
**Prefijo Godot:** `res://` (relativo a esa carpeta)

---

## Resumen del juego

Roguelite de minería espacial por **rondas**. El jugador alterna entre un **hub de metajuego** (SkillMenu) y **expediciones de minería** (game.tscn). Cada ronda tiene límite de **CO₂** (oxígeno), cuota de minerales y posible boss ore al completar la profundidad máxima.

**Loop:**
```
MainMenu → SkillMenu (hub) → game.tscn (ronda) → RoundEndScreen (recap) → SkillMenu → ...
```

> Nova Miner adapta este loop con base física explorables y bloques ore en grilla. Esta referencia usa hub UI y ores sueltos.

---

## Autoloads

Definidos en `res://project.godot`:

| Autoload | Escena / Script | Propósito |
|---|---|---|
| `GameManager` | `scenes/global/GameManager.tscn` + `scripts/global/GameManager.gd` | Save, progreso, refs runtime, cuotas, desbloqueos |
| `EventBus` | `scripts/global/EventBus.gd` | Bus de señales global |
| `SceneManager` | `scripts/global/SceneManager.gd` | Cambio de escena, overlays, pausa |
| `Transition` | `scenes/global/Transition.tscn` + `scripts/global/Transition.gd` | Animación wipe entre escenas |
| `UpgradeManager` | `scripts/global/UpgradeManager.gd` | Upgrades permanentes, procs, artefactos |
| `CurrencyManager` | `scenes/global/CurrencyManager.tscn` + `scripts/global/CurrencyManager.gd` | Monedas, minerales, pickup visual |
| `GameStats` | `scenes/global/GameStats.tscn` + `scripts/global/GameStats.gd` | StatBlocks duplicados por ronda |
| `QuotaManager` | `scripts/global/QuotaManager.gd` | Cuota de minería y boss |
| `SoundManager` | `scenes/global/SoundManager.tscn` | Audio |
| `InteractionManager` | `scenes/global/InteractionManager.tscn` + `scripts/global/InteractionManager.gd` | Prompt `[E]` y dispatch |
| `ComboManager` | `scripts/global/ComboManager.gd` | Combo por kills de enemigos |
| `SynergyManager` | `scripts/global/SynergyManager.gd` | Sinergias entre procs |
| `ObjectPoolManager` | (UID autoload) | Pool de VFX/proyectiles |
| `HoverIndicator` | (UID autoload) | Indicador visual de ore bajo raycast |
| `CommandConsole` | `scenes/global/CommandConsole.tscn` | Consola debug |

**Grupos globales:** `Player`, `Enemy`, `Boss`, `Walls`, `Ores`

**Physics layers:** Player (1), Player HurtBox (2), Wall Collision (3), Ore HitBox (4), Enemy (5)

---

## 1. Game Loop y flujo de escenas

### Escenas clave

| Escena | Script | Rol |
|---|---|---|
| `scenes/ui/main_menu.tscn` | `scripts/main_menu.gd` | Menú inicial (`run/main_scene`) |
| `scenes/SkillMenu.tscn` | `scripts/skill_menu.gd` | Hub de metajuego |
| `scenes/ui/planet_selector.tscn` | — | Selector mundo/profundidad |
| `scenes/game.tscn` | `scripts/game.gd` | Ronda activa de minería |
| `scenes/ui/round_end_screen.tscn` | `scripts/ui/round_end_screen.gd` | Recap post-ronda |
| `scenes/ui/ui.tscn` | `scripts/ui.gd` (`RoundUI`) | HUD in-run |
| `scenes/ui/upgrade_choice_ui.tscn` | — | Elección de upgrade mid-run |
| `scenes/ui/escape_menu.tscn` | — | Pausa con Escape |
| `scenes/ui/options_menu.tscn` | — | Opciones |

### Flujo paso a paso

1. **MainMenu** → Start → `SceneManager.change_scene("res://scenes/SkillMenu.tscn")`
2. **SkillMenu** → al entrar convierte minerales → dinero (`skill_menu.gd` → `_add_money()`)
3. **Play / PlanetSelector** → `GameManager.setup_quota()` → carga `game.tscn`
4. **Game** `_ready` → conecta CO₂ bar, setea refs en `GameManager`
5. **RoundManager** `_ready` → `EventBus.round_start` → spawnea player + bots
6. **SpawnManager** → genera ores → `EventBus.spawns_initialized`
7. **Durante ronda** → minar, XP, upgrades mid-run, cuota, boss
8. **Fin** → `EventBus.round_over` → `GameManager._round_over()` → overlay `round_end_screen.tscn`
9. **RoundEndScreen** → Continue → SkillMenu; New Run → `game.tscn`

### Clases relacionadas

- `scripts/game.gd` — escena de ronda, wiring inicial
- `scripts/skill_menu.gd` — hub, conversión ore→money, botón Play
- `scripts/main_menu.gd` — entrada al juego
- `scripts/ui/round_end_screen.gd` (`class_name RoundEndScreen`) — recap animado
- `scripts/ui.gd` (`class_name RoundUI`) — HUD CO₂, cuota, monedas

---

## 2. SceneManager y Transition

### SceneManager
**Archivo:** `scripts/global/SceneManager.gd`

| Método | Uso |
|---|---|
| `change_scene(path, direction, title, subtitle)` | Cambio completo con wipe animado |
| `change_overlay(path, pause_game)` | Overlay sobre escena actual |
| `remove_overlay()` | Cierra overlay, emite `EventBus.show_ui` |
| `defer_overlay(path, delay)` | Overlay con delay |

- Pausa el árbol si hay overlay con pausa o transición activa.
- Escape abre `escape_menu.tscn` (excepto en RoundEndScreen).

### Transition
**Archivos:** `scenes/global/Transition.tscn`, `scripts/global/Transition.gd`

- Enum `SlideDirection { LEFT, RIGHT, TOP, BOTTOM }`
- Señal `on_transition_finished`
- Timing: 0.5s slide in, 0.75s hold, slide out
- Emite `EventBus.hide_ui` / `show_ui`

### Rutas habituales

| Origen → Destino | Dirección | Título |
|---|---|---|
| MainMenu → SkillMenu | BOTTOM | "UPGRADES" |
| SkillMenu → game.tscn | BOTTOM | Nombre del planeta |
| RoundEnd → SkillMenu | TOP | — |

---

## 3. GameManager

**Archivos:** `scripts/global/GameManager.gd`, `scenes/global/GameManager.tscn`

### Responsabilidades
- Persistencia (`user://save.tres`)
- Progreso por mundo/profundidad
- Referencias runtime durante la ronda
- Setup de cuota y validación de spawn

### Referencias runtime (no autoload Refs)

```gdscript
var player: Player
var camera: Camera2D
var current_tool: BaseMiningTool
var effect_layer: Node2D
var round_scene: Node2D
var spawn_manager: SpawnManager
var spawn_rect: Rect2
var ui_juice: Node
```

### Save — `SaveGame`
**Archivo:** `scripts/strategies/SaveGame.gd`

Contiene: `upgrade_data`, `currency_data`, `world_progress`, `skill_levels`, tool unlocks/equips/upgrades, settings, `first_round`, discovery flags.

### Métodos clave

| Método | Qué hace |
|---|---|
| `_load_or_create_save()` | Carga o crea save |
| `save_progress()` | Persiste estado |
| `reset_save()` | Borra progreso |
| `setup_quota(world_id, level_id)` | Delega a QuotaManager |
| `get_spawn_pos(padding, check_pos)` | Posición aleatoria sin overlap con ores (min 10px) |
| `get_display_worlds()` / `get_display_levels()` | Gating de desbloqueos |

### Data configurada en escena
- `world_entries: Dictionary[int, WorldEntry]` — export en `GameManager.tscn`

### Conexiones
- `EventBus.upgrade_purchased` → `save_progress`
- `EventBus.round_start` → `_round_start`
- `EventBus.player_dead` → `_round_over`

### Clases de progreso
- `scripts/strategies/WorldProgress.gd`
- `scripts/strategies/LevelProgress.gd`

---

## 4. EventBus — Todas las señales

**Archivo:** `scripts/global/EventBus.gd`

### Enum ProcEvent
```gdscript
enum ProcEvent {
    MINE_HIT, ORE_MINED, ENEMY_KILLED, PROJECTILE_HIT,
    LIGHTNING_HIT, BOMB_EXPLOSION, VORTEX_DAMAGE, MISSILE_HIT, SPLINTER_HIT
}
```

### Señales

| Señal | Args | Emisor típico | Receptor típico |
|---|---|---|---|
| `round_start` | — | RoundManager | GameManager, GameStats |
| `round_over` | `player_dead, message` | RoundManager, SpawnManager | GameManager, Player |
| `player_spawned` | — | Player (landing) | SpawnManager, RoundUI, QuotaManager |
| `player_dead` | `message` | Player | GameManager |
| `spawns_initialized` | — | SpawnManager | RoundManager (habilita CO₂) |
| `consume_co2` | `amount` | Mining behaviors | RoundManager (intención) |
| `add_xp` | `amount` | CurrencyManager | LevelComponent, QuotaManager |
| `xp_update` | `current, max, level` | LevelComponent | UI |
| `upgrade_purchased` | — | SkillButton | GameManager, ButtonController |
| `upgrade_selected` | — | upgrade_choice_ui | LevelComponent |
| `currency_ui_update` | — | CurrencyManager | SkillMenu, RoundUI |
| `proc_event` | `ProcEvent, ProcContext` | Mining, SpawnManager | UpgradeManager, SynergyManager |
| `boss_hp_update` | `current, max` | SpawnManager | RoundUI |
| `hide_ui` / `show_ui` | — | SceneManager | RoundUI |
| `artifact_acquired` | `id` | Artifact pickup | — |
| `enemy_spawned` / `enemy_dead` | — | Enemy systems | ComboManager |
| `set_dash_bar_max` | — | Player dash | UI |
| `crt_update` | `enable` | GameManager settings | CRT effect |
| `round_initialized` | — | — | — |
| `player_health_update` | `current, max` | HealthComponent | UI |
| `focus_update` | `current` | — | — |
| `unlock_skills` | — | — | — |

---

## 5. RoundManager — CO₂ y ciclo de ronda

**Archivo:** `scripts/components/RoundManager.gd`  
**Escena padre:** `scenes/game.tscn`

### Ciclo de vida

1. `_ready()` → `EventBus.round_start.emit()`
2. `_reset_round_state()` — limpia currency run, pools, artefactos, rebuild procs
3. `_setup_spawns()` — spawnea `player.tscn`, equipa tool, spawnea N `bot_base.tscn`
4. Espera `EventBus.spawns_initialized` → `can_consume = true`
5. `_process()` — drena CO₂ mientras player vivo

### Fórmula CO₂
```
total_level = (world - 1) * 5 + level
mult = pow(1.5, total_level - 1)  # con dampening post nivel 5/10
co2_multiplier = mult * co2_drain_factor
```
Al llegar a 0: `EventBus.round_over.emit(true, "OUT OF CO2")`

### Señales propias
- `co2_changed(current, max)` → `RoundUI.update_co2_bar`

### Clases relacionadas
- `scripts/components/SpawnerComponent.gd` — helper de spawn
- `scripts/components/RoundManager.gd`
- Stats: `GameStats.player_stats` (`max_co2`, `current_co2`, `co2_drain_factor`)

---

## 6. SpawnManager — Generación de ores

**Archivo:** `scripts/components/SpawnManager.gd`  
**Escena padre:** `scenes/game.tscn` (Node2D)

### Respuestas directas (importante para Nova Miner)

| Pregunta | Respuesta |
|---|---|
| ¿Bloques tipo Minecraft? | **No** — sprites sueltos en posiciones aleatorias |
| ¿TileMap para ores? | **No** — TileMap es suelo decorativo (3 capas, z_index -10/-9/-7) |
| ¿YSort? | **Sí** — `arena_node`, `round_scene`, cada ore sprite, player |
| ¿Profundidad? | Posición Y en mundo; sombras en z_index -1 |
| ¿Server-side registry? | **Sí** — `ore_server_registry: Dictionary[RID → data]` |
| ¿OreNodeBase activo? | **No** en spawn path principal |

### ore_server_registry

Cada entrada keyed por **hit RID** (PhysicsServer2D):
```gdscript
{
    type, hp, max_hp, sprite, pos, variation,
    base_rid, middle_point, active_effects, is_boss, ...
}
```

**Dos RIDs por ore:**
- `base_rid` — rectángulo layer 3 (Wall Collision) — bloquea movimiento
- `hit_rid` — círculo layer 4 (Ore HitBox) — queries de minería

### Spawning
- Trigger: `EventBus.player_spawned`
- Cantidad inicial: stat `starting_ore_amount`
- Respawn timer: `ore_respawn_timer` → spawnea `ore_spawn_amount` ores
- Peso por tipo: `LevelData.ores` → `OreSpawnData`
- Peso por tamaño: stats `weight_small/medium/big`
- Cap: `max_ores_on_screen` (default 100)
- Posición: `GameManager.get_spawn_pos(40, true)` — min 10px separación

### Boss ore
- `spawn_boss_level_ore()` — ore gigante, limpia ores cercanos, `is_boss: true`
- Al minar: `EventBus.round_over.emit(..., "BOSS MINED!")`

### Daño
- `damage_ore_by_rid(rid, damage, attack_type)` — path principal de minería
- Al romper: `CurrencyManager.spawn_ore()`, `EventBus.proc_event(ORE_MINED)`

### Pools visuales
- `sprite_pool`, `flash_pool`, `shadow_pool` — Sprite2D reutilizables

### Legacy (no usado en spawn activo)
- `scripts/ore_node_base.gd` + `scenes/ores/OreNodeBase.tscn`

---

## 7. Player — Movimiento e input

**Archivos:** `scenes/player.tscn`, `scripts/player.gd` (`class_name Player`)

### Componentes
| Componente | Archivo |
|---|---|
| MovementComponent | `scripts/components/MovementComponent.gd` |
| AnimationComponent | `scripts/components/AnimationComponent.gd` |
| Game camera | `scripts/game_camera.gd` |

### Input actions
`move_left/right/up/down`, `left_click`, `right_click`, `dash`, `interact`, `escape`, `slot_1/2/3`, `mouse_movement`

### Movimiento
- WASD o mouse-chase (toggle `GameManager.move_with_mouse` con F)
- Dash: Space, 3× speed, cooldown de stat `dash_cooldown_time`
- `MovementComponent.move()` — lerp velocity, knockback, `move_and_slide`
- Tool rota hacia aim; flip en X para pickaxe/hammer

### Minería
- `_physics_process`: mouse pos → `current_tool.current_aim_pos`
- `set_casting_active(Input.is_action_pressed("left_click"))`
- `try_mining()` cada frame mientras click held

### Spawn
- Cae desde y=-600, animación landing → `EventBus.player_spawned`
- `GameManager.player = self`

### Estados
`is_spawning`, `is_dashing`, `is_dead`, `is_digging` (dig-deeper incompleto)

---

## 8. Herramientas de minería (especialmente Láser)

### Base
**Archivo:** `scripts/base_mining_tool.gd` (`class_name BaseMiningTool`)  
**Escena base:** `scenes/BaseMiningTool.tscn`

### Pipeline de minería
```
Player.try_mining()
  → BaseMiningTool._mine()
    → TargetingComponent.acquire_targets() → Array[RID]
    → MiningBehavior.execute(targets)
      → SpawnManager.damage_ore_by_rid()
```

### Escenas de herramientas

| Tool | Escena | Targeting | Behavior |
|---|---|---|---|
| Pickaxe | `scenes/tool_pickaxe.tscn` | `MouseTargetingComponent` | `PickaxeBehavior` |
| Drill | `scenes/tool_drill.tscn` | `RaycastTargeting` | `DrillBehavior` |
| **Laser** | `scenes/tool_laser.tscn` | `RaycastTargeting` | `LaserBehavior` |
| Flamethrower | `scenes/tool_flamethrower.tscn` | `AoeTargeting` | `FlamethrowerBehavior` |
| Hammer | `scenes/tool_hammer.tscn` | `AoeTargeting` | `HammerBehavior` |

### Targeting components
| Componente | Archivo | Método |
|---|---|---|
| MouseTargeting | `scripts/components/MouseTargeting.gd` | Radio en mouse, range check |
| RaycastTargeting | `scripts/components/RaycastTargeting.gd` | Ray hacia mouse, HoverIndicator |
| AoeTargeting | `scripts/components/AoeTargeting.gd` | Shape overlap |

### Laser — detalle

| Aspecto | Clase / Archivo |
|---|---|
| Behavior | `scripts/resources/laser_behavior.gd` (`LaserBehavior`) |
| Raycast visual | `scripts/laser_raycast.gd` (extends RayCast2D) |
| Beam | Line2D + particles, crece a `max_length` 1400 a `cast_speed` 7000 |
| Targeting | RID del collider vs `ore_server_registry` |
| Daño | Single target, crit roll, `AttackType.LASER` |
| CO₂ por hit | 0.5 (`EventBus.consume_co2.emit(0.5)`) |
| Cooldown | 0.05s (rapid fire mientras held) |
| Input | Hold `left_click` |

### Mining behaviors (Strategy pattern)
**Base:** `scripts/resources/mining_behavior.gd`  
Implementaciones: `pickaxe_behavior.gd`, `laser_behavior.gd`, `drill_behavior.gd`, `flamethrower_behavior.gd`, `hammer_behavior.gd`

### Proc abilities en tools
Chain lightning, bomb, vortex, drill missile, nova splinter — vía `EventBus.proc_event`

---

## 9. Ore Nodes y componentes

### Path activo (server registry)
- Visual: pooled `Sprite2D` + shadow child
- Physics: `PhysicsServer2D` bodies (no nodos Godot)
- Status: `SpawnManager.apply_status_to_rid()` + burn ticks en `_process`
- Break: debris, `CurrencyManager.spawn_ore()`, procs

### Path legacy (OreNodeBase — no usado en spawn activo)

| Clase | Archivo |
|---|---|
| OreNodeBase | `scripts/ore_node_base.gd` + `scenes/ores/OreNodeBase.tscn` |
| HealthComponent | `scripts/components/HealthComponent.gd` |
| DropComponent | `scripts/components/DropComponent.gd` |
| StatusEffectsComponent | `scripts/components/StatusEffectsComponent.gd` |
| AnimationComponent | `scripts/components/AnimationComponent.gd` |
| OreVariation | `scripts/strategies/OreVariation.gd` |

---

## 10. CurrencyManager

**Archivos:** `scripts/global/CurrencyManager.gd`, `scenes/global/CurrencyManager.tscn`

### CurrencyData
**Archivo:** `scripts/strategies/CurrencyData.gd`
- `OreType`: RED, PURPLE, BLUE, BLACK, YELLOW, GREEN, STONE
- `CurrencyType`: MONEY, SCREW
- `ore_amount`, `currency_amount`, `*_acquired_this_run`, modifiers

### Pickup system
- `spawn_ore(type, pos)` — `RenderingServer` canvas item (no Node)
- Burst 0.15s → homing 700px/s → collect en 10px
- `add_ore()` → batch XP/quota cada 4 frames

### Conversión en hub
`skill_menu.gd` → `_add_money()` convierte `ore_amount` → MONEY via `get_ore_value()`

### Señales
- Emite `EventBus.currency_ui_update`

---

## 11. QuotaManager

**Archivo:** `scripts/global/QuotaManager.gd`

| Método / Señal | Qué hace |
|---|---|
| `setup_quota(LevelProgress, max_quota)` | Init desde GameManager |
| `add_quota(amount)` | Incrementa; al max → `quota_reached`, save |
| `quota_update(current, max)` | → RoundUI bar |
| Boss trigger | Final level + quota reached → `spawn_manager.spawn_boss_level_ore()` |
| `_dig_deeper()` | Siguiente profundidad (código incompleto — sin callers) |

---

## 12. UpgradeManager

**Archivo:** `scripts/global/UpgradeManager.gd`

| Método | Qué hace |
|---|---|
| `rebuild_proc_chance()` | Agrega ProcUpgrade chances por event |
| `apply_stats_to_new_object(type, StatBlock)` | Aplica upgrades a stats |
| `apply_all_artifacts()` / `apply_new_artifact(id)` | Artefactos permanentes |
| `apply_ore_upgrades()` | Modifiers de valor de ore → CurrencyData |
| `_on_proc_event` | Rolls de proc en `EventBus.proc_event` |
| `add_upgrade()` | Compra desde SkillButton |

### Tipos de upgrade
**Archivo:** `scripts/strategies/UpgradeData.gd`  
Enum: `PLAYER`, `TOOLS`, `ORES`, `ENEMIES`, `PROCS`, `DRONES`

### Sub-recursos
- `scripts/strategies/StatUpgrade.gd`
- `scripts/strategies/EventUpgrade.gd`
- `scripts/strategies/ProcUpgrade.gd`
- `scripts/strategies/OreValueUpgrade.gd`
- `scripts/strategies/ArtifactData.gd`

---

## 13. SkillMenu — Hub de metajuego

**Archivos:** `scenes/SkillMenu.tscn`, `scripts/skill_menu.gd`

> Equivalente conceptual de Nova Miner `base_zone`, pero como **UI con pestañas**, no base física.

### Tabs controller
**Archivo:** `scripts/ui/tabs_controller.gd`

| Pestaña | Script / Contenido | Equivalente Nova Miner |
|---|---|---|
| Skill Tree | `scripts/button_controller.gd` + `SkillButton` | UpgradeTree |
| Tools | `scripts/tools_menu.gd` | WeaponShop |
| Artifacts | `scripts/artifacts_menu.gd` | — |
| Select | overlay `planet_selector.tscn` | Selector de misión |
| Play | lanza `game.tscn` | Puerta a mine_zone |
| Settings | `options_menu.tscn` | OptionsMenu |

### Skill Tree
- `scripts/button_controller.gd` — canvas zoom/pan, líneas de prerequisitos
- `scripts/components/SkillButton.gd` — nodo individual, compra con MONEY/SCREW
- Pan: right-click drag; zoom: scroll wheel

### Tools tab
- Carousel de herramientas
- Equip → `SaveGame.equipped_tool_id`
- 3 upgrades por tool con tornillos (SCREW) desde `ToolUnlock` resources

### Al entrar al hub
- Convierte ores → MONEY
- Muestra planeta/profundidad seleccionados

---

## 14. RoundEndScreen — Recap

**Archivos:** `scenes/ui/round_end_screen.tscn`, `scripts/ui/round_end_screen.gd` (`class_name RoundEndScreen`)

### Flujo
1. Espera pickups aéreos
2. `GameManager.player.is_dead = true`
3. Muestra ores, tornillos, artefactos de la run
4. Anima barra de cuota `starting_quota` → `end_quota`
5. Tween contador de dinero
6. **Continue** → SkillMenu; **New Run** → `game.tscn`
7. Limpia flag `first_round`

### Data sources
- `GameManager.starting_quota`, `end_quota`, `max_quota`
- `CurrencyManager.currency_data.ores_acquired_this_run`
- `UpgradeManager.upgrade_data.artifacts_acquired_this_run`

---

## 15. InteractionManager

**Archivos:** `scenes/global/InteractionManager.tscn`, `scripts/global/InteractionManager.gd`

| Clase | Archivo | Rol |
|---|---|---|
| InteractionManager | `scripts/global/InteractionManager.gd` | Prompt + dispatch E |
| InteractionAreaComponent | `scripts/components/InteractionArea.gd` | Registro enter/exit |

### Flujo
1. Area registra en player body enter/exit
2. `_process`: ordena por distancia, muestra `"[E] to {action_name}"`
3. `_input`: acción `interact` → `await active_areas[0].interact.call()` (cooldown 1s)

**Usado en ronda:** cofres (`chest_base.gd`), artefactos (`artifact_base.gd`). **No en hub.**

---

## 16. StatBlock / GameStats

### StatBlock
**Archivo:** `scripts/strategies/StatBlock.gd` (`class_name StatBlock`)

```gdscript
get_stat(name) = (base + flat) * (1 + percent) * multiplier
```

Campos: `base_stats`, `flat_bonus`, `percent_bonus`, `multiplier`, `flags`, `lists`

### GameStats
**Archivos:** `scripts/global/GameStats.gd`, `scenes/global/GameStats.tscn`

En `round_start` duplica bases:
| Base | Aplica upgrades de |
|---|---|
| `player_stats_base` → `player_stats` | PLAYER |
| `ores_stats_base` → `ores_stats` | ORES |
| `loot_stats_base` | — |
| `enemy_stats_base` | ENEMIES |

### Stats player relevantes
`max_co2`, `current_co2`, `co2_drain_factor`, `mining_damage`, `movement_speed`, `bots_unlocked`, proc stats, dash cooldown

### Stats ore relevantes
`starting_ore_amount`, `ore_respawn_timer`, `ore_spawn_amount`, `weight_small/medium/big`

### Archivos .tres
`scripts/resources/stats/player_stats_base.tres`, subresources en `GameStats.tscn`

---

## 17. Resources de datos (Level, World, Ore)

| Resource | Archivo | Campos clave |
|---|---|---|
| **WorldEntry** | `scripts/strategies/WorldEntry.gd` | `world_name`, `level_entries`, `artifacts[]`, `ambient_color`, `reward_tool_id` |
| **LevelEntry** | `scripts/strategies/LevelEntry.gd` | `level_data`, `level_progress` |
| **LevelData** | `scripts/strategies/LevelData.gd` | `max_quota`, `ores[]`, `stone_data`, `enemy_data[]` |
| **LevelProgress** | `scripts/strategies/LevelProgress.gd` | `current_quota`, `quota_reached`, `boss_mined` |
| **WorldProgress** | `scripts/strategies/WorldProgress.gd` | `depth_progress: Dictionary[int, LevelProgress]` |
| **OreData** | `scripts/strategies/OreData.gd` | `ore_name`, `ore_type`, `ore_value`, sprites, boss |
| **OreSpawnData** | `scripts/strategies/OreSpawnData.gd` | `ore_data`, `ore_weight` |
| **OreVariation** | `scripts/strategies/OreVariation.gd` | size, textures, HP, amount, collision shapes |
| **SaveGame** | `scripts/strategies/SaveGame.gd` | Persistencia completa |
| **ToolUnlock** | (resources en scenes) | Upgrades de herramienta con SCREW |

Configuración multi-mundo en `scenes/global/GameManager.tscn` (5 profundidades, cuotas escaladas 100→250→...)

---

## 18. Bots / Ayudantes

### Mining bots
**Archivos:** `scripts/bot_base.gd`, `scenes/bot_base.tscn`

| Aspecto | Detalle |
|---|---|
| Spawn | RoundManager según stat `bots_unlocked` |
| Targeting | Ore más cercano no targeteado en `ore_server_registry` (1000px) |
| Flag | `is_targeted = true` mientras asignado |
| Movimiento | `MovementComponent` |
| Minería | 5px range, `bot_damage` stat, `AttackType.PICKAXE` |
| Daño | `SpawnManager.damage_ore_by_rid()` |

### Drone upgrades
`UpgradeData.drone_unlocks` — pickaxe/drill/flame/laser/hammer drones  
Sincronizado por `UpgradeManager`

### Otros helpers
| Sistema | Archivo | Rol |
|---|---|---|
| ComboManager | `scripts/global/ComboManager.gd` | Multiplicador por kills |
| SynergyManager | `scripts/global/SynergyManager.gd` | Cross-proc mutations |
| ObjectPoolManager | (autoload) | VFX/projectiles pooled |
| HoverIndicator | (autoload) | Bracket UI en ore target |
| CommandConsole | `scenes/global/CommandConsole.tscn` | Debug |

---

## 19. Level-up mid-run

**Archivo:** `scripts/components/LevelComponent.gd`

- Escucha `EventBus.add_xp`
- Al subir nivel → overlay `upgrade_choice_ui.tscn`
- Selección → `EventBus.upgrade_selected`

---

## 20. Flujo completo de minería (diagrama)

```
left_click (held)
  → Player.try_mining()
    → BaseMiningTool._mine()
      → TargetingComponent.acquire_targets()
        → MouseTargeting / RaycastTargeting / AoeTargeting
      → MiningBehavior.execute(targets)
        → LaserBehavior / PickaxeBehavior / ...
          → SpawnManager.damage_ore_by_rid(rid, damage, attack_type)
            → HP update, EventBus.proc_event(MINE_HIT)
            → on break:
                → CurrencyManager.spawn_ore(type, pos)
                → homing pickup → add_ore()
                → EventBus.add_xp + QuotaManager.add_quota()
                → EventBus.proc_event(ORE_MINED)
```

---

## 21. Índice rápido por tema

| Tema | Clases principales |
|---|---|
| Cambio de escena | `SceneManager.gd`, `Transition.gd` |
| Save / progreso | `GameManager.gd`, `SaveGame.gd`, `WorldProgress.gd`, `LevelProgress.gd` |
| Señales globales | `EventBus.gd` |
| Inicio/fin ronda | `RoundManager.gd`, `round_end_screen.gd` |
| Spawn ores | `SpawnManager.gd`, `LevelData.gd`, `OreSpawnData.gd` |
| Daño a ore | `SpawnManager.damage_ore_by_rid()` |
| Player input | `player.gd`, `MovementComponent.gd` |
| Láser | `tool_laser.tscn`, `laser_behavior.gd`, `laser_raycast.gd`, `RaycastTargeting.gd` |
| Pickup | `CurrencyManager.gd`, `CurrencyData.gd` |
| Cuota / boss | `QuotaManager.gd`, `SpawnManager.spawn_boss_level_ore()` |
| Upgrades permanentes | `UpgradeManager.gd`, `UpgradeData.gd`, `SkillButton.gd` |
| Hub UI | `skill_menu.gd`, `tabs_controller.gd`, `button_controller.gd`, `tools_menu.gd` |
| Stats runtime | `GameStats.gd`, `StatBlock.gd` |
| Interacción E | `InteractionManager.gd`, `InteractionArea.gd` |
| Bots | `bot_base.gd`, stat `bots_unlocked` |
| Mundos / niveles | `WorldEntry.gd`, `LevelEntry.gd`, `LevelData.gd`, `OreData.gd` |
| HUD in-run | `ui.gd` (RoundUI) |
| Mid-run upgrades | `LevelComponent.gd`, `upgrade_choice_ui.tscn` |
| Procs / sinergias | `UpgradeManager.gd`, `SynergyManager.gd`, `ProcUpgrade.gd` |
| Object pooling | `ObjectPoolManager` |
| Hover ore target | `HoverIndicator`, `RaycastTargeting.gd` |

---

## 22. Diferencias clave vs Nova Miner

| Aspecto | Deep Space Miner | Nova Miner (objetivo) |
|---|---|---|
| Hub | UI tabs (SkillMenu) | Base física explorables (base_zone) |
| Ores | Sprites sueltos + server registry | Bloques en grilla estilo Minecraft 2D |
| YSort | Sí (ores sueltos) | Sí (bloques en grilla) |
| Targeting | Raycast/mouse radius continuo | Click mouse para seleccionar bloque |
| Ayudantes | Bots (`bot_base`) — unlock en skill tree | Helpers — unlock cantidad en UpgradeTree, mods en Helper Station |
| CO₂ | `StatBlock.current_co2` drain | `StatsData.oxygen` (por definir) |
| Refs | `GameManager.player` etc. | `Refs.player` + `GameManager` |

Ver `nova_miner.md` para la visión del proyecto nuevo.
