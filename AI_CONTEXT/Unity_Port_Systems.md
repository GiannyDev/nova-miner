# Nova Miner → Unity Port Guide

> Documento para recrear los sistemas core de **Nova Miner / Tiny Drillers** en Unity.
> Stack Unity asumido: **DOTween** + **Feel (MoreMountains)** para game feel.
> Origen Godot: este repo. Leé este archivo entero antes de implementar.

---

## 1. Qué es el juego (1 párrafo)

Incremental de minería 2D top-down/isométrico-light: el player entra a una mina infinita, se mueve libremente, perfora bloques de ore con un drill, y cuando se agota la **drill durability** termina la run → **Recap** → vuelve a base o reminea. En base gasta ores en **UpgradeTree** (y más adelante WeaponShop / CompanionWorkshop).

**Loop:**
```
Base → MineZone (INTRO → PLAYING) → Durability 0 → Recap → Base | Replay Mine
```

**Pilares a respetar:**
1. Performance (pooling, budget de spawn por frame, sin trabajo inútil cada frame)
2. Mina infinita: ores solo dentro de una ventana de celdas que sigue al player
3. Game feel (squash, spawn pop, damage text, ore drops, UI reveal)
4. Data-driven: ScriptableObjects = Resources de Godot

---

## 2. Arquitectura de la mina (orden de responsabilidades)

```
MineZone (orquestador de run)
├── MineGrid          → celdas infinitas, ocupación, reservas, cell↔world
├── MineChunk         → ventana móvil WHERE (no WHEN)
├── OreSpawner        → WHEN + cuántos + qué tipo; cola + refill
├── OrePool           → acquire/release (nunca Destroy en runtime)
├── YSort / World
│   ├── Player
│   │   └── DrillWeapon
│   └── Ore[] (pooled)
└── UI (Inventory, Durability, RecapMenu, Perks)
```

**Contrato crítico:**
| Sistema | Decide |
|---|---|
| `MineGrid` | Coordenadas + ocupación |
| `MineChunk` | **Dónde** se puede spawnear (ventana) |
| `OreSpawner` | **Cuándo** y **cuántos** (refill, destroy procs) |
| `OrePool` | Reutilización de instancias |
| `Player` + `DrillWeapon` | Movimiento + daño a ores |
| `MineZone` | Intro, tracking de run, fin → Recap |

---

## 3. MineGrid — espacio de celdas infinito

### Idea
No hay Tilemap infinito. Es un diccionario de celdas `Vector2Int → stackHeight`. Celdas negativas son válidas. El “piso” es conceptual; el player camina sobre el mundo continuo.

### Conversiones
```
cellSize = layout.cellSize   // default Godot ~ (128, 62) o (256, 158) según layout
world = cell * cellSize      // centro de celda en origen (0,0)
cell  = Round(world / cellSize)  // Round, no Floor — crítico para negativos
```

### Ocupación / reservas
- `occupied[cell] = stackHeight` (0 = libre, erase)
- `reserved[cell] = true` → nunca spawnea (spawn del player, props)
- `IsFreeForSpawn(cell)` = no occupied && no reserved
- Al spawnear stack: `AddStackOccupation` por cada bloque
- Al destruir: `RemoveStackOccupation`; libera solo al llegar a 0

### Posición del bloque en mundo
```
oreWorldPos = CellToWorld(cell) + layout.GetStackOffset(stackIndex)
// GetStackOffset: (0, cellCenterOffsetY - stackRiseY * stackIndex)
```
Varios ores pueden compartir footprint (misma celda, distinto `stackIndex`).

### Unity
- MonoBehaviour `MineGrid` con `Dictionary<Vector2Int, int> occupied` y `HashSet<Vector2Int> reserved`.
- `MineBlockLayout` → ScriptableObject (blockWidth/Height, cellSize, cellCenterOffsetY).
- Debug draw opcional con Gizmos / GL (solo cuando cambia el rect visible o zoom).

---

## 4. MineChunk — ventana que sigue al player

### Idea
Rectángulo de celdas (`chunkSizeCells`, tipicamente **21×20**) centrado en el player + **lookahead** en dirección de movimiento. Solo se recentra cuando el player cruza `refreshStepCells` (dead-zone). Emite `OnWindowMoved` → el spawner hace refill.

### Reglas
- `windowCells = RectInt(center - size/2, size)`
- `center = playerCell + Round(moveDir * lookaheadCells)`
- Si quieto → sin lookahead
- Debe ser **mayor** que la vista de cámara (si no, se ven ores apareciendo)
- Modifiers temporales de tamaño (skills) vía `AddSizeModifier(id, extraCells, duration)`

### Unity
- `MineChunk : MonoBehaviour`, FixedUpdate con early-out si no cruzó dead-zone.
- C# event `Action<RectInt> OnWindowMoved`.
- No instancia ores. Solo acota WHERE.

---

## 5. OreSpawner + OrePool — generación infinita

### Densidad objetivo
```
targetCount = PlayerStats.STARTING_ORE_AMOUNT  // upgradeable
pending = activeOres.Count + spawnQueue.Count
missing = targetCount - pending
```
Mantener ~`targetCount` ores vivos cerca. Refill en tick (`refillInterval` ~0.25s) + al mover ventana + al destruir.

### Cola y budget
1. Elegir celdas → encolar `Vector3Int(x, y, stackIndex)`
2. Cada frame: drenar cola con `maxSpawnsPerFrame` (~24)
3. Separar **elegir** de **instanciar** = no hitch

### Placement (MineSpawnProfile SO)
| Campo | Rol |
|---|---|
| `safeZoneSize` | NxN alrededor del player: nunca spawn |
| `startClearanceCells` | Reserva al entrar (área libre) |
| `nearPlayerBias` | % spawns cerca (resto random en chunk) |
| `nearSpawnRadius` | Radio Chebyshev “cerca” |
| `forwardBiasRatio` | De los “cerca”, % empujados en dirección de move |
| `clusterChance` / `clusterSpread` | Vetas: pegar al batch actual |
| `minedCellBanSeconds` | Ban temporal de celda minada (anti-respawn) |
| `oreWeights[]` | Weighted random de `OreData` |
| `stackChance` / `maxStackHeight` | Stacks opcionales |
| `spawnAnimationTime` | Pop de aparición |

### Al destruir un ore
```
BanCell(sourceCell)
if rand <= SPAWN_ON_DESTROY_CHANCE → +1
+ SPAWN_ORE_WHEN_DESTROYED_AMOUNT (stat flat)
if rand <= SPAWN_CLUSTER_CHANCE → scatter(SPAWN_CLUSTER_SIZE)
RequestRefill()
```
Extras **no** anclados a la celda rota: scatter en el chunk.

### Pool contract
```
OnSpawned(): reset HP, visible, colliders on, scale 1
OnDespawned(): kill tweens, hide, colliders off, detach parent
```
**Nunca** `Destroy`/`queue_free` un ore en run. Pool con prewarm.

### Unity
- `OrePool` con `Stack<Ore>` / List inactive.
- Spawner en Update: drain queue + expire bans; refill solo en estado `Playing`.
- Physics layers: Player vs Ore StaticBody.

---

## 6. Ore (bloque)

### Estado
- `maxHp` / `currentHp` desde `OreData` + size (SMALL/MED/LARGE)
- `gridCell`, `stackIndex`, `oreData`
- Sprites por umbral HP: 100% / 75% / 50% / 25%
- Signal/event `Destroyed(Ore)`

### Daño
```
TakeDamage(amount):
  if lethal → Destroy()
  else → squash feel + refresh sprite

DestroyInstant(): kill sin squash (oneshot del drill)
Destroy():
  hide YA, colliders off (anti-teleporte al hueco)
  grid.RemoveStackOccupation(cell)
  emit RunOreDestroyed
  spawn OreDrops visuales
  emit Destroyed → pool release
```

### Feel (Unity)
| Momento | Godot | Unity (Feel/DOTween) |
|---|---|---|
| Hit no letal | Springer.squash | MMFeedbacks Scale / SquashStretch |
| Spawn mid-run | scale 0→1 BackOut | DOTween `DOScale` Ease.OutBack |
| Intro rise | scale.y 0→1 BackOut | DOScaleY OutBack |
| Destroy | hide inmediato | disable renderer+collider YA |

Dos colliders típicos (cuerpo + top) para apilar / y-sort.

---

## 7. Player + Drill — interacción con bloques

### Movimiento
- Input vector normalizado (WASD / stick)
- Speed desde `PLAYER_SPEED` (stats)
- `CharacterController` / Rigidbody2D kinematic + `Move`
- **Si drill engaged → hard stop** (no slide al hueco)

### DrillWeapon (composición, no en el Player monolítico)

Contacto = **Area2D tip del drill ∪ slide collisions del body**.

#### Latch vs Oneshot (regla de oro)
```
damage >= ore.currentHp  → ONESHOT
  - Rompe al tocar, sin frenar player
  - VFX burst corto
  - NO latch / NO hold

damage < ore.currentHp   → MULTI-HIT
  - Latch al ore más cercano al tip
  - Player se frena (shouldHoldPlayer)
  - Golpes cada hitDelay (WeaponData)
  - Squash en chips; último golpe = destroy + holdGrace breve (~0.08s)
```

#### Hold player
```
shouldHold = isDrilling || holdTimer > 0
```
Al soltar input de movimiento → release latch + clear hold.

#### Aim
Solo dirección de movimiento / último facing. **Nunca** apunta al ore (evita flick al destruir).

#### Damage text
Al hit: spawn floating text en marker del ore, dirección = opuesta al aim (Feel: `MMFeedbackFloatingText` o prefab + DOTween jump).

### Durability (fin de run)
- `drillDurabilityMax` en stats; current se drena cada frame en PLAYING
- Al llegar a 0 → `DrillDurabilityDepleted` → MineZone.endRun → Recap
- Sin durability → no perfora

### Unity mapping
- Player: `PlayerController` + `MovementComponent` + child `DrillWeapon`
- Layers: Ore StaticCollider; Drill Contact = Trigger
- Feel: particles al perforar (`MMFeedbackParticles`), camera shake leve opcional, squash en ore

---

## 8. OreDrop → inventario

Al destruir:
1. 1/2/3 drops visuales según size (no es cantidad de inventario; cada drop suele sumar 1)
2. Pop scale → caída + 2 rebotes laterales (DOTween secuencial)
3. Curva jump al icono HUD del ore (`Feedbacks.do_jump` ≈ DOJump / path bezier)
4. Shrink + pulse del display → `CurrencyManager.AddOre`

---

## 9. UpgradeTree

### Data
`StatUpgrade` (ScriptableObject):
- `id` único (save key)
- `statId` (enum Stats)
- `costOre` (enum Ores)
- `costs[]` / `values[]` paralelos (nivel = índice)
- `operationMode`: Flat / Percent / Multiplier
- `operationType`: Add / Subtract / SetTrue / SetFalse

### Runtime
`UpgradeManager.Purchase(upgrade)`:
1. Check max level + afford ore
2. Spend ore
3. `stats.ModifyStat(statId, value, mode, op)`
4. `levels[id]++`
5. Save + emit events

### UI nodos
- Cada `UpgradeNode` referencia `StatUpgrade` + `previousSkills[]`
- Visible solo si prerequisites tienen `level > 0`
- Compra vía manager; UI no aplica stats a mano

### Reveal (Feel/DOTween)
Cascada estilo ShellDiver:
1. Roots pop (scale + rotación → 0, flash)
2. Olas BFS: línea crece hacia hijo → hijo pop
3. Timings exportables (nodeReveal ~0.22, lineGrow ~0.14, siblingStagger ~0.045)
4. Al comprar: mini-cascada solo a nodos recién desbloqueados

Pan/zoom del árbol con drag derecho + wheel.

### Stats relevantes al port
```
STARTING_ORE_AMOUNT
PLAYER_SPEED, PLAYER_DMG, PLAYER_ATTACK_COOLDOWN
SPAWN_ORE_WHEN_DESTROYED_AMOUNT, SPAWN_ON_DESTROY_CHANCE
SPAWN_CLUSTER_CHANCE, SPAWN_CLUSTER_SIZE
DRILL_DURABILITY_MAX
(+ unlocks shops más adelante)
```

---

## 10. Recap

### Tracking en MineZone (solo PLAYING)
| Stat | Cómo |
|---|---|
| `oresCollected[id]` | delta positivo de `OreAmountChanged` |
| `blocksMined` | cada `RunOreDestroyed` |
| `damageDealt` | `Player.dealtDamage` |
| `distanceTraveled` | Manhattan en celdas (1 cell = 1m) |

### Snapshot
`RunRecapData`: ore ids a mostrar, amounts, blocks, damage, distance.

### Secuencia UI (simple, sin presets complejos)
1. Fade BG + título
2. Todos los paneles de stats juntos (sin texto) ~0.2s
3. Textos en cadena con count-up + stagger ~0.08s
4. Botones Home / Play pop BackOut
5. Records panel slide-in; si hay NEW record → scale.x 0→1 OutBack + tag “NEW”

### Records
`SaveData` guarda best blocks / damage / distance. Recap llama `ApplyRunRecords` y marca cuáles se rompieron.

### Botones
- Home → Base scene
- Play → MineZone de nuevo

---

## 11. Game state + managers (singletons)

```
GameStates: None | Intro | Playing | Paused | GameOver

INTRO:
  delay player → spawn batch colapsado → rise all → BeginRun()

PLAYING:
  movimiento, spawn refill, drain durability, tracking

PAUSED:
  Recap / menús
```

Singletons sugeridos Unity:
| Godot Autoload | Unity |
|---|---|
| GameManager | GameManager |
| EventBus | EventBus / C# events estáticos |
| UpgradeManager | UpgradeManager |
| CurrencyManager | CurrencyManager |
| SaveData | SaveData (JSON + .bak) |
| Transition | SceneFader |
| Feedbacks | Feedbacks (DOTween helpers) o Feel players |
| Refs | RuntimeRefs (player, inventory) |

---

## 12. Intro de mina (orden exacto)

```
state = INTRO
repair drill full
spawn player at world 0
reserve entry area around player
chunk.Follow(player)
introSpawnMode = true
spawnInitialBatch + flushQueue   // todos listos, scale.y=0
introSpawnMode = false
await delay
playIntroRiseAll(duration)      // todos a la vez
state = PLAYING
emit OnRunStarted
```

---

## 13. Data / ScriptableObjects a crear

1. `MineBlockLayout` — cell size, offsets
2. `MineSpawnProfile` — safe zone, biases, weights, ban time
3. `OreData` + `OreDefinition` (size → hp, sprites)
4. `OreSpawnEntry` (oreData + weight)
5. `StatsData` — stats vivos del player
6. `StatUpgrade` — nodos del árbol
7. `WeaponData` — hitDelay, spin, damage mult
8. `RunRecapData` — snapshot (puede ser plain C# class)
9. `PerkData` — opcional mid-run (ya hay UI de tooltip)

Todo tunnable en Inspector. Cero magic numbers en hot paths.

---

## 14. Performance checklist (Unity)

- [ ] Pool de ores; nunca Destroy en destroy path
- [ ] Spawn budget por frame
- [ ] Chunk dead-zone (no recalcular ventana cada FixedUpdate si no cruzó step)
- [ ] Dictionaries de celdas; no escanear escena
- [ ] `sqrMagnitude` en distancias
- [ ] Collider cull offscreen solo si medís necesidad (rompe hits fuera de cámara)
- [ ] Refill por timer/señal, no cada frame “busy loop”
- [ ] Kill tweens al despawn (DOTween `Kill`, Feel stop)

---

## 15. Mapa Feel / DOTween (atajos)

| Feedback | Preferencia |
|---|---|
| Ore squash hit | Feel SquashAndStretch / Scale |
| Ore spawn pop | DOTween OutBack |
| Ore intro rise | DOScaleY OutBack |
| Damage numbers | Feel FloatingText o prefab + DOJump |
| OreDrop bounce + home | DOTween sequence + DOJump path |
| Inventory pulse | DOPunchScale |
| Upgrade reveal | DOTween sequence (line fill + pop) |
| Recap panels | DOFade + DOScale BackOut |
| Drill particles | Feel Particles / Unity VFX |
| UI button hover | DOPunchRotation / Feel |

Springer (Godot) ≈ springs de Feel o DOTween con elastic/overshoot controlado.

---

## 16. Orden de implementación recomendado (otro chat)

1. **MineGrid + BlockLayout** (celdas, debug draw)
2. **MineChunk** (ventana + follow + event)
3. **Ore + OrePool** (spawn/despawn manual)
4. **OreSpawner + SpawnProfile** (batch + refill + ban)
5. **Player movement**
6. **DrillWeapon** (oneshot vs latch — probar feel primero)
7. **OreDrop + Currency + Inventory HUD**
8. **Durability + MineZone run lifecycle + Intro**
9. **Recap + Save records**
10. **Stats + UpgradeManager + UpgradeTree UI**
11. **Juice pass** con Feel/DOTween

No implementes WeaponShop / Workshop / maps×submines hasta que el loop mina↔recap↔upgrades esté sólido.

---

## 17. Decisiones de diseño no negociables

1. Chunk = WHERE, Spawner = WHEN.
2. Oneshot no frena; multi-hit sí (hold + grace anti-teleporte).
3. Aim del drill ≠ dirección al ore.
4. Pool siempre; hide + collider off **antes** de feedback largo al morir.
5. Stats solo vía ScriptableObjects / StatsData; UI no escribe gameplay a mano.
6. Recap mide solo durante PLAYING.
7. Celdas negativas válidas; `Round` en world→cell.

---

## 18. Referencias de código Godot (este repo)

| Sistema | Path |
|---|---|
| Grid | `scenes/zones/mine_zone/mine_grid.gd` |
| Chunk | `scenes/zones/mine_zone/mine_chunk.gd` |
| Spawner | `scenes/zones/mine_zone/ore_spawner.gd` |
| Pool | `scenes/zones/mine_zone/ore_pool.gd` |
| MineZone | `scenes/zones/mine_zone/mine_zone.gd` |
| Ore | `scenes/ore/ore.gd` |
| OreDrop | `scenes/ore/ore_drop.gd` |
| Player | `scenes/player/player.gd` |
| Drill | `scenes/player/drill_weapon.gd` |
| UpgradeTree | `scenes/ui/upgrade_tree/upgrade_tree.gd` |
| UpgradeNode | `scenes/ui/upgrade_tree/upgrade_node.gd` |
| Recap | `scenes/ui/recap_menu/recap_menu.gd` |
| Stats enum | `scripts/enums/stats.gd` |
| StatsData | `data/stats_data.gd` |
| StatUpgrade | `data/upgrades/stat_upgrade.gd` |
| SpawnProfile | `data/mines/mine_spawn_profile.gd` |
| BlockLayout | `data/mines/mine_block_layout.gd` |
| Vision / Loop | `AI_CONTEXT/00_Vision.md`, `02_Game_Loop.md` |
| Perf | `AI_CONTEXT/03_Performance_Rules.md` |

---

*Generado desde el estado real del proyecto Nova Miner (Godot). Usalo como brief único para el chat de Unity.*
