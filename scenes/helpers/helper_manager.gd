extends Node
class_name HelperManager
## Spawnea N ayudantes al comenzar la run.

const HELPER_SCENE := preload("res://scenes/helpers/helper.tscn")

@export var helper_data: HelperData

var helpers: Array[Helper] = []
var spawner: OreSpawner
var host: Node2D
var marker_layer: OffscreenMarkerLayer


func setup(ore_spawner: OreSpawner, parent: Node2D, markers: OffscreenMarkerLayer) -> void:
	spawner = ore_spawner
	host = parent
	marker_layer = markers


## Instancia Stats.HELPERS_UNLOCKED mineros en el hueco de spawn.
func spawn_run_helpers(origin_cell: Vector2i) -> void:
	clear_helpers()
	var count := maxi(int(Stats.get_stat(Stats.HELPERS_UNLOCKED)), 0)
	if count <= 0 or helper_data == null:
		return
	for i in count:
		var helper := HELPER_SCENE.instantiate() as Helper
		host.add_child(helper)
		var start := origin_cell + spawn_offset(i)
		helper.setup(spawner, helper_data, start)
		helpers.append(helper)
		if marker_layer != null:
			marker_layer.register_target(helper)


func spawn_offset(index: int) -> Vector2i:
	var ring: Array[Vector2i] = [
		Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN,
		Vector2i(-1, -1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(1, 1),
	]
	return ring[index % ring.size()]


func clear_helpers() -> void:
	for helper in helpers:
		if not is_instance_valid(helper):
			continue
		helper.shutdown()
		if marker_layer != null:
			marker_layer.unregister_target(helper)
		helper.queue_free()
	helpers.clear()
