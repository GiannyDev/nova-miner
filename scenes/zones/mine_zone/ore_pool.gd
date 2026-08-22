extends Node
class_name OrePool

@export var ore_scene: PackedScene
@export var prewarm_count: int = 0

var available: Array[Ore] = []
var total_created: int = 0

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
	var scene := resolve_ore_scene()
	if scene == null or not scene.can_instantiate():
		push_error("OrePool: PackedScene de ore invalida (path vacio o sin nodos).")
		return null

	var ore := scene.instantiate() as Ore
	if ore == null:
		push_error("OrePool: la escena asignada no tiene script Ore.")
		return null

	total_created += 1
	return ore


## Inspector vacio a veces llega como PackedScene "" (node count 0), no como null.
func resolve_ore_scene() -> PackedScene:
	if ore_scene != null and ore_scene.can_instantiate():
		return ore_scene
	return Refs.ORE_SCENE


## Saca el bloque del arbol y lo guarda como disponible (nodo huerfano, sin fisica ni dibujo).
func detach(ore: Ore) -> void:
	if not is_instance_valid(ore):
		return

	var parent := ore.get_parent()
	if parent != null:
		parent.remove_child(ore)

	if not available.has(ore):
		available.append(ore)
