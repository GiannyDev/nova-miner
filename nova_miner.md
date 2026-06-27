# Nova Miner — Documentación del Juego

> Documento de referencia para futuros chats. Describe la visión completa, el loop de juego, controles, estaciones, sistemas y estado actual del proyecto.

---

## Resumen

**Nova Miner** es un roguelite de minería espacial en **2D top-down**. El jugador alterna entre una **base explorable** (estilo lobby de Soul Knight) y **expediciones a la mina**, donde recolecta minerales con un láser antes de que se agote el oxígeno o el tiempo.

El loop principal:

```
Base Zone → (puerta + transición) → Mine Zone → Recap → (transición) → Base Zone
```

En la base se invierten recursos en mejoras permanentes. En la mina se obtienen esos recursos minando bloques de ore.

---

## Loop de juego

### 1. Base Zone — Lobby

**Escena:** `res://scenes/zones/base_zone/base_zone.tscn`  
**Script:** `res://scenes/zones/base_zone/base_zone.gd` (`class_name BaseZone`)

La base es un espacio 2D donde el jugador se mueve libremente e interactúa con **estaciones físicas**. Cada estación tiene un `Area2D` (detector) que detecta al jugador y abre un panel de UI.

Al entrar a la base:
- El player ya está instanciado en escena (persiste entre sesiones de base).
- `BaseZone` registra al player en `Refs.player`.
- El jugador puede moverse, acercarse a estaciones y salir por la puerta hacia la mina.

Al volver de una run:
- Se muestra el recap (overlay).
- Tras confirmar, transición de vuelta a la base con los recursos obtenidos.

### 2. Mine Zone — Run

**Escena:** `res://scenes/zones/mine_zone/mine_zone.tscn` (por implementar)

Al salir por la puerta de la base:
1. Transición animada entre escenas.
2. Se carga `mine_zone.tscn`.
3. Se instancia al player en posición de spawn.
4. Se generan **bloques de ore proceduralmente**.
5. Comienza el drenaje de oxígeno (o timer de run).
6. El jugador mina, recolecta y sobrevive hasta el fin de la run.

### 3. Fin de run — Recap

Cuando se agota el oxígeno o el tiempo (mecánica por definir):
1. Se pausa el gameplay.
2. Overlay de recap: minerales obtenidos, stats de la run, progreso.
3. Botón para volver a la base → transición → `base_zone.tscn`.

---

## Controles

| Acción | Input |
|---|---|
| Movimiento | **WASD** (`move_up`, `move_down`, `move_left`, `move_right`) |
| Seleccionar / minar ore | **Click izquierdo del mouse** sobre el bloque objetivo |
| Interactuar con estación | Proximidad + acción (por definir, ej. `E`) |
| Pausa / opciones | Por definir |

### Movimiento (WASD)

- Input vectorial con `Input.get_vector("move_left", "move_right", "move_up", "move_down")`.
- El player es un `CharacterBody2D` con animación Spine.
- Stats de velocidad en `StatsData.speed` (`res://resources/data/player/stats_data.gd`).

### Minería (mouse + click)

- El jugador **apunta con el mouse** hacia el bloque de ore.
- **Click izquierdo** selecciona el objetivo y activa el láser.
- El láser sale desde `LaserFirePos` (Marker2D en `player.tscn`).
- Arma: `res://scenes/weapon/weapon_laser.tscn` (`class_name WeaponLaser`).
- Stats relevantes: `attack`, `attack_cooldown`, `laser_length`, `pickup_radius`.

> **Diferencia con la referencia:** Deep Space Miner usa raycast continuo mientras se mantiene click. Nova Miner puede usar click para seleccionar + minar; el diseño final se alineará con la sensación deseada, pero la intención es **mouse como selector de objetivo**.

---

## Estaciones de la Base (3 iniciales)

Todas viven bajo el nodo `YSort` de `base_zone.tscn` para respetar profundidad visual con el player.

| Estación | Panel UI | Propósito |
|---|---|---|
| **Workbench** | `UpgradeTree` | Árbol de mejoras permanentes del jugador y **desbloqueo de ayudantes** (solo cantidad). |
| **Weapon Station** | `WeaponShop` | Desbloquear y mejorar **láseres** (armas de minería). |
| **Helper Station** | Panel de ayudantes (por crear) | Modificar ayudantes ya desbloqueados: stats, comportamiento, eficiencia. |

### Workbench → UpgradeTree

- **Escena panel:** `res://scenes/ui/upgrade_tree/upgrade_tree.tscn`
- **Script:** `res://scenes/ui/upgrade_tree/upgrade_tree.gd` (`class_name UpgradeTree`)
- Compras permanentes con moneda acumulada.
- Aquí se **desbloquean ayudantes** y se aumenta **cuántos** pueden spawnear en la mina.
- No se configuran stats individuales del ayudante aquí; eso es rol de la Helper Station.

### Weapon Station → WeaponShop

- **Escena panel:** `res://scenes/ui/weapon_shop/weapon_shop.tscn`
- Desbloqueo de nuevos tipos de láser.
- Mejoras de daño, cooldown, longitud, etc.
- Datos en `res://resources/data/weapons/weapon_data.gd` (`class_name WeaponData`).

### Helper Station → Ayudantes

- Panel dedicado (aún no existe en escena; reemplaza conceptualmente el uso de `OreRefinery` como estación).
- Los ayudantes se **desbloquean y aumentan en cantidad** desde el UpgradeTree.
- En la Helper Station se **modifican** para que ayuden más: daño, velocidad, rango, prioridad de targets, etc.
- En la mina, los ayudantes spawnean automáticamente según cuántos tengas desbloqueados (similar a `bot_base` en la referencia).

### Interacción estación → panel

Patrón previsto:
1. Player entra en `PlayerDetector` (Area2D) de la estación.
2. Se muestra prompt de interacción o se abre el panel automáticamente.
3. `GUI` (`res://scenes/zones/base_zone/gui.gd`) gestiona visibilidad de paneles.
4. Vignette shader (`res://resources/shaders/vignette.gdshader`) da feedback visual al abrir UI.

---

## Mine Zone — Bloques de Ore (estilo Minecraft 2D)

### Concepto

Los minerales en Nova Miner son **bloques discretos en una grilla**, no ores flotantes sueltos como en Deep Space Miner.

- Vista **top-down 2D**.
- Bloques apilables: uno puede estar **delante o detrás** de otro según su posición Y.
- Todos los bloques y el player viven bajo un nodo **`YSort`** con `y_sort_enabled = true`.
- Profundidad visual = posición Y en mundo (igual criterio que la referencia, pero con bloques en grilla).

### Generación procedural

- Al iniciar la run, un **spawn manager** genera bloques en posiciones de grilla dentro del área de mina.
- Tipos de ore definidos en `OreData` (`res://resources/data/ores/ore_data.gd`).
- Pesos, rareza y distribución configurables vía Resources (no hardcode).
- Los bloques tienen HP, tipo de mineral, y drop al destruirse.

### Estructura de escena prevista

```
MineZone
├── YSort                    ← y_sort_enabled = true
│   ├── Player               ← instanciado al entrar
│   ├── OreBlock (×N)        ← bloques generados proceduralmente
│   └── Helpers (×N)         ← según desbloqueos del UpgradeTree
├── SpawnManager             ← generación procedural
├── RoundManager             ← oxígeno / timer / fin de run
└── GUI                      ← HUD in-run (oxígeno, recursos, etc.)
```

### Comparación con la referencia (Deep Space Miner)

| Aspecto | Nova Miner | Deep Space Miner (referencia) |
|---|---|---|
| Forma del ore | **Bloques en grilla** (Minecraft 2D) | Sprites sueltos en posiciones aleatorias |
| YSort | **Sí** — bloques + player bajo `YSort` | **Sí** — ores + player bajo `YSort` |
| TileMap para ores | Bloques como nodos/escenas | TileMap solo decorativo (suelo), ores separados |
| Targeting | Click del mouse sobre bloque | Raycast / mouse radius hacia ore RID |
| Registry server-side | Por evaluar (rendimiento con muchos bloques) | Sí — `ore_server_registry` + PhysicsServer2D |

---

## Sistemas y arquitectura

### Autoloads actuales

| Autoload | Archivo | Rol |
|---|---|---|
| `Refs` | `res://autoloads/refs.gd` | Referencias globales (`player`, etc.) |
| `EventBus` | `res://autoloads/event_bus.gd` | Señales globales desacopladas |
| `GameManager` | `res://autoloads/game_manager.gd` | Estado del juego, save/load, estados (`PLAYING`, `PAUSED`, `GAMEOVER`) |
| `UpgradeManager` | `res://autoloads/upgrade_manager.gd` | Aplica upgrades del árbol al `StatsData` del player |
| `Springer` | `res://autoloads/springs/springer.gd` | Utilidad de animación spring |
| `Sound` | `res://autoloads/sound_manager/sound_manager.gd` | Audio |

### Autoloads por crear (inspirados en referencia)

| Autoload | Rol previsto |
|---|---|
| `SceneManager` | Transiciones entre base ↔ mina, overlays (recap, pausa) |
| `CurrencyManager` | Monedas, minerales, pickup visual |
| `RoundManager` | Oxígeno, inicio/fin de run en mine_zone |

### Resources de datos

| Resource | Archivo | Contenido |
|---|---|---|
| `StatsData` | `res://resources/data/player/stats_data.gd` | `attack`, `attack_cooldown`, `oxygen`, `speed`, `laser_length`, `pickup_radius` |
| `OreData` | `res://resources/data/ores/ore_data.gd` | Tipo, valor, sprites, HP del bloque |
| `WeaponData` | `res://resources/data/weapons/weapon_data.gd` | Stats del láser |

### Physics layers

Definidos en `project.godot`:
- Layer 1: **Player**
- Layer 2: **Ore**

### Convenciones de código

Seguir `godot_guideline.md`:
- Composición sobre monolitos.
- `@export` y Resources para datos configurables.
- Señales vía `EventBus`.
- Orden de script: exports → `@onready` → variables → built-in → funciones → bool → conexiones.
- Sin `_` en variables; `_` solo en funciones conectadas a señales.

---

## UI existente

| Panel | Escena | Estado |
|---|---|---|
| UpgradeTree | `scenes/ui/upgrade_tree/upgrade_tree.tscn` | Stub |
| WeaponShop | `scenes/ui/weapon_shop/weapon_shop.tscn` | Stub |
| OreRefinery | `scenes/ui/ore_refinery/ore_refinery.tscn` | Existe; reevaluar si se usa o se reemplaza por Helper Station |
| OptionsMenu | `scenes/ui/options_menu/options_menu.tscn` | Stub |
| PauseMenu | `scenes/ui/pause_menu/pause_menu.tscn` | Stub |
| Recap (fin de run) | — | Por crear |

**GUI manager:** `res://scenes/zones/base_zone/gui.gd` (`class_name GUI`)

---

## Player

**Escena:** `res://scenes/player/player.tscn`  
**Script:** `res://scenes/player/player.gd` (`class_name Player`)

- `CharacterBody2D` con Spine (`Hero_1.skel`).
- `LaserFirePos` — punto de origen del láser.
- Movimiento WASD (por implementar en script).
- Minería con mouse (por implementar).
- Stats aplicados desde `UpgradeManager` → `StatsData`.

---

## Ayudantes (Helpers)

### Desbloqueo (UpgradeTree)
- Nodo en el árbol de mejoras desbloquea el **tipo** de ayudante.
- Upgrades adicionales en el árbol aumentan la **cantidad** que spawnea en la mina.

### Modificación (Helper Station)
- Mejoras específicas por ayudante: daño, velocidad, rango de detección, cadencia.
- Separado del árbol general para no mezclar meta-progresión con tuning de compañeros.

### Comportamiento en mina (referencia: `bot_base.gd`)
- Buscan el ore más cercano no targeteado.
- Se mueven hacia él y minan automáticamente.
- Spawnean según `bots_unlocked` equivalente en Nova Miner.

---

## Transiciones

Patrón inspirado en Deep Space Miner (`SceneManager` + `Transition`):
- **Base → Mina:** wipe/slide animado, carga `mine_zone.tscn`.
- **Mina → Recap:** overlay sobre escena actual (pausa juego).
- **Recap → Base:** transición de vuelta a `base_zone.tscn`.

Por implementar como autoload `SceneManager` + escena `Transition.tscn`.

---

## Fin de run — condiciones

Por definir entre:
- **Oxígeno** (`StatsData.oxygen`) — drenaje pasivo por segundo (como CO₂ en referencia).
- **Timer fijo** — duración máxima de la expedición.
- Posible combinación de ambos.

Al activarse → emitir señal en `EventBus` → mostrar recap → volver a base.

---

## Estado actual del proyecto

| Componente | Estado |
|---|---|
| Base zone (escena + player + 1 estación) | Parcial |
| GUI con paneles instanciados | Stub |
| Mine zone | Vacía (solo nodo raíz) |
| Player movement / mining | Stub |
| Weapon laser | Clase vacía |
| UpgradeTree / WeaponShop | Stub |
| Helper system | No existe |
| SceneManager / transiciones | No existe |
| Recap screen | No existe |
| Ore blocks procedural | No existe |
| EventBus señales | Vacío |
| Save/load | No implementado |

**Escena principal:** `base_zone.tscn` (`run/main_scene` en `project.godot`)

---

## Mapeo conceptual: Nova Miner ↔ Referencia

| Nova Miner | Deep Space Miner |
|---|---|
| `base_zone.tscn` | `SkillMenu.tscn` (hub) |
| Estaciones físicas + paneles | Pestañas UI (Skill Tree, Tools, Artifacts) |
| `mine_zone.tscn` | `game.tscn` |
| Bloques ore en grilla + YSort | Ores sueltos + YSort + server registry |
| `UpgradeTree` | Skill Tree (`ButtonController`) |
| `WeaponShop` | Tools tab (`tools_menu.gd`) |
| Helper Station | Bot upgrades + `bot_base.tscn` |
| Recap overlay | `round_end_screen.tscn` |
| `StatsData.oxygen` | `StatBlock.current_co2` |
| `Refs.player` | `GameManager.player` |

Para detalle técnico de la referencia, ver `deep_space_miner_reference.md`.
