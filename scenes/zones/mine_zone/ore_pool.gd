extends Node
class_name OrePool
## Pool de bloques Ore reutilizables: evita instanciar/liberar mientras el player se mueve.
## Vive dentro de la escena de la mina para no filtrar nodos entre cambios de escena.

# --- Exports ---
## Escena del bloque. Si esta vacia usa Refs.ORE_SCENE.
@export var ore_scene: PackedScene
## Bloques creados al entrar a la mina para que los primeros spawns no instancien nada.
@export var prewarm_count: int = 0

# --- Runtime ---
var available: Array[Ore] = []
var total_created: int = 0


# --- Built-ins ---
func _ready() -> void:
	prewarm(prewarm_count)


## Los bloques en reposo viven fuera del arbol: hay que liberarlos a mano.
func _exit_tree() -> void:
	for ore in available:
		if is_instance_valid(ore):
			ore.queue_free()
	available.clear()


# --- Public API ---
## Saca un bloque listo (reciclado o nuevo) y lo cuelga del parent de juego.
func acquire(parent: Node) -> Ore:
	var ore: Ore = available.pop_back() if not available.is_empty() else create_ore()
	if ore == null:
		return null

	if ore.get_parent() != parent:
		if ore.get_parent() != null:
			ore.get_parent().remove_child(ore)
		parent.add_child(ore)

	ore.visible = false
	ore.reset_physics_interpolation()
	return ore


## Devuelve el bloque al pool. Lo apaga ya y lo saca del arbol de forma diferida (viene de fisica).
func release(ore: Ore) -> void:
	if ore == null or not is_instance_valid(ore):
		return

	ore.on_despawned()
	detach.call_deferred(ore)


func prewarm(count: int) -> void:
	for i in count:
		var ore := create_ore()
		if ore == null:
			return
		ore.on_despawned()
		available.append(ore)


func get_available_count() -> int:
	return available.size()


# --- Private helpers (no leading _) ---
func create_ore() -> Ore:
	var scene := ore_scene if ore_scene != null else Refs.ORE_SCENE
	if scene == null:
		push_error("OrePool: sin ore_scene ni Refs.ORE_SCENE.")
		return null

	var ore := scene.instantiate() as Ore
	if ore == null:
		push_error("OrePool: la escena asignada no tiene script Ore.")
		return null

	total_created += 1
	return ore


## Saca el bloque del arbol y lo guarda como disponible (nodo huerfano, sin fisica ni dibujo).
func detach(ore: Ore) -> void:
	if not is_instance_valid(ore):
		return

	var parent := ore.get_parent()
	if parent != null:
		parent.remove_child(ore)

	if not available.has(ore):
		available.append(ore)
