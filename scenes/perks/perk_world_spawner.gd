extends Node
class_name PerkWorldSpawner
## Coloca N pickups a distancia del spawn. UNKNOWN se reserva; al revelar se talla el hueco.

const PICKUP_SCENE := preload("res://scenes/perks/perk_pickup.tscn")

var spawner: OreSpawner
var host: Node2D
var marker_layer: OffscreenMarkerLayer
var pickups: Array[PerkPickup] = []


func setup(ore_spawner: OreSpawner, parent: Node2D, markers: OffscreenMarkerLayer) -> void:
	spawner = ore_spawner
	host = parent
	marker_layer = markers
	if not spawner.perk_cell_carved.is_connected(_on_perk_cell_carved):
		spawner.perk_cell_carved.connect(_on_perk_cell_carved)


## Elige celdas a `perk_min_distance_cells` y las registra en el spawner.
func stamp_run_perks() -> void:
	clear_pickups()
	var profile := spawner.profile
	if profile == null or profile.perk_count <= 0 or profile.perk_pool.is_empty():
		return
	var origin := Vector2i.ZERO
	if spawner.grid != null and Refs.player != null:
		origin = spawner.grid.world_to_cell(Refs.player.global_position)
	var used := {}
	for i in profile.perk_count:
		var data: PerkData = profile.perk_pool[i % profile.perk_pool.size()]
		var cell := pick_perk_cell(origin, profile.perk_min_distance_cells, used)
		used[cell] = true
		spawner.register_perk_cell(cell, data)


func pick_perk_cell(origin: Vector2i, min_distance: int, used: Dictionary) -> Vector2i:
	var dist := maxi(min_distance, 6)
	for attempt in 12:
		var angle := randf() * TAU
		var cell := origin + Vector2i(roundi(cos(angle) * dist), roundi(sin(angle) * dist))
		if used.has(cell):
			continue
		return cell
	return origin + Vector2i(dist, 0)


func spawn_pickup_at(cell: Vector2i, perk_data: PerkData) -> void:
	var pickup := PICKUP_SCENE.instantiate() as PerkPickup
	host.add_child(pickup)
	pickup.setup(perk_data, cell, spawner.get_cell_world_position(cell))
	pickup.collected.connect(_on_pickup_collected)
	pickups.append(pickup)
	if marker_layer != null:
		marker_layer.register_target(pickup)


func clear_pickups() -> void:
	for pickup in pickups:
		if not is_instance_valid(pickup):
			continue
		if marker_layer != null:
			marker_layer.unregister_target(pickup)
		pickup.queue_free()
	pickups.clear()


func _on_perk_cell_carved(cell: Vector2i, perk_data: PerkData) -> void:
	spawn_pickup_at(cell, perk_data)


func _on_pickup_collected(pickup: PerkPickup) -> void:
	if marker_layer != null:
		marker_layer.unregister_target(pickup)
	pickups.erase(pickup)
