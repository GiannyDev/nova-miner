extends Node2D
class_name RefineryBench

@export var refined_ore_stack_y_gap: float = 12.0
@export var max_visible_refined: int = 10
@export var deposit_stagger: float = 0.05
@export var collect_stagger: float = 0.05
@export var fly_duration: float = 0.45
@export var arc_height: float = 90.0
@export var player_spawn_offset: Vector2 = Vector2(0, -48)
@export var ore_data: OreData

@onready var refine_ore_pos: Marker2D = $RefineOrePos
@onready var refinery_machine_pos: Marker2D = $RefineryMachinePos
@onready var refined_container: Node2D = $RefinedContainer

var is_player_colliding: bool = false
var is_depositing: bool = false
var is_collecting: bool = false
var is_refining: bool = false

var refined_count: int = 0
var settling_refined: int = 0
var pending_collect_flights: int = 0

var visible_refined: Array[Node2D] = []
var refined_ore_ids: Array[String] = []
var refine_queue: Array[String] = []


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("interact"):
		return
	if not is_player_colliding:
		return
	if GameManager.curr_state != GameManager.GameStates.PLAYING:
		return
	if is_depositing or is_collecting:
		return

	if GameManager.has_raw_ores():
		deposit_ores_to_machine()
		return

	if refined_count > 0 and settling_refined <= 0:
		move_refined_ores_to_player()


## Deposita ores mientras se mantiene E. Al soltar, deja de depositar.
func deposit_ores_to_machine() -> void:
	is_depositing = true

	while can_keep_depositing():
		var ore_id: String = GameManager.take_next_raw_ore()
		launch_raw_ore_to_machine(ore_id)
		await get_tree().create_timer(deposit_stagger).timeout

	is_depositing = false


func can_keep_depositing() -> bool:
	return (
		Input.is_action_pressed("interact")
		and is_player_colliding
		and GameManager.has_raw_ores()
		and GameManager.curr_state == GameManager.GameStates.PLAYING
	)


func launch_raw_ore_to_machine(ore_id: String) -> void:
	var drop: Node2D = Refs.ORE_DROP_SCENE.instantiate()
	add_child(drop)
	drop.global_position = Refs.player.global_position + player_spawn_offset
	drop.scale = Vector2.ZERO

	var pop := create_tween()
	pop.tween_property(drop, "scale", Vector2.ONE, 0.12)\
		.set_trans(Tween.TRANS_BACK)\
		.set_ease(Tween.EASE_OUT)

	await animate_arc(
		drop,
		drop.global_position,
		refinery_machine_pos.global_position,
		fly_duration,
		arc_height
	)

	drop.queue_free()
	enqueue_refine(ore_id)


## Cola de refine: un ore a la vez durante ore_data.refine_wait_time.
func enqueue_refine(ore_id: String) -> void:
	refine_queue.append(ore_id)
	process_refine_queue()


func process_refine_queue() -> void:
	if is_refining:
		return

	is_refining = true
	while not refine_queue.is_empty():
		var ore_id: String = refine_queue.pop_front()
		await get_tree().create_timer(ore_data.refine_wait_time).timeout
		deposit_refined_ore_to_bench(ore_id)
	is_refining = false


## Sale del machine al stack del bench. Si ya hay max visibles, solo suma al conteo.
func deposit_refined_ore_to_bench(ore_id: String) -> void:
	refined_ore_ids.append(ore_id)

	if visible_refined.size() + settling_refined >= max_visible_refined:
		refined_count += 1
		return

	settling_refined += 1
	var slot_index := visible_refined.size() + settling_refined - 1
	var target := get_stack_global_position(slot_index)

	var refined: Node2D = Refs.REFINED_ORE_SCENE.instantiate()
	refined_container.add_child(refined)
	refined.global_position = refinery_machine_pos.global_position
	refined.scale = Vector2.ZERO

	var pop := create_tween()
	pop.tween_property(refined, "scale", Vector2.ONE, 0.12)\
		.set_trans(Tween.TRANS_BACK)\
		.set_ease(Tween.EASE_OUT)

	await animate_arc(refined, refined.global_position, target, fly_duration, arc_height)

	refined.global_position = target
	visible_refined.append(refined)
	refined_count += 1
	settling_refined -= 1


## Recoge refined: exceso invisible primero, luego stack de arriba hacia abajo.
func move_refined_ores_to_player() -> void:
	is_collecting = true
	var total := refined_count

	for i in total:
		var ore_id: String = refined_ore_ids.pop_back()
		var refined_id := GameManager.get_refined_id(ore_id)

		if refined_count > visible_refined.size():
			refined_count -= 1
			launch_refined_to_player(spawn_refined_at_stack_top(), refined_id)
		else:
			refined_count -= 1
			launch_refined_to_player(visible_refined.pop_back(), refined_id)

		if i < total - 1:
			await get_tree().create_timer(collect_stagger).timeout

	while pending_collect_flights > 0:
		await get_tree().process_frame

	is_collecting = false


func launch_refined_to_player(refined: Node2D, refined_id: String) -> void:
	pending_collect_flights += 1

	var target := Refs.player.global_position + player_spawn_offset
	var global_pos := refined.global_position
	if refined.get_parent() != self:
		refined.reparent(self, true)
		refined.global_position = global_pos

	await animate_arc(refined, refined.global_position, target, fly_duration, arc_height)

	GameManager.add_ore(refined_id, 1)
	refined.queue_free()
	pending_collect_flights -= 1


func spawn_refined_at_stack_top() -> Node2D:
	var refined: Node2D = Refs.REFINED_ORE_SCENE.instantiate()
	add_child(refined)
	refined.global_position = get_stack_top_global_position()
	return refined


func get_stack_global_position(index: int) -> Vector2:
	return refine_ore_pos.global_position + Vector2(0, -refined_ore_stack_y_gap * index)


func get_stack_top_global_position() -> Vector2:
	if visible_refined.is_empty():
		return refine_ore_pos.global_position
	return visible_refined.back().global_position


## Arco: sube y cae hacia el destino.
func animate_arc(
	node: Node2D,
	from: Vector2,
	to: Vector2,
	duration: float,
	height: float
) -> void:
	var control := Vector2(
		lerpf(from.x, to.x, 0.35),
		minf(from.y, to.y) - height
	)

	var tween := create_tween()
	tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_method(
		func(t: float) -> void:
			node.global_position = quadratic_bezier(from, control, to, t),
		0.0,
		1.0,
		duration
	)
	await tween.finished


func quadratic_bezier(p0: Vector2, p1: Vector2, p2: Vector2, t: float) -> Vector2:
	var u := 1.0 - t
	return (u * u * p0) + (2.0 * u * t * p1) + (t * t * p2)


func _on_player_detector_body_entered(body: Node2D) -> void:
	if body is Player:
		is_player_colliding = true


func _on_player_detector_body_exited(body: Node2D) -> void:
	if body is Player:
		is_player_colliding = false
