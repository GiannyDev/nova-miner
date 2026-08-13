extends Control
class_name UpgradeTree

@onready var world = %World
@onready var upgrade_nodes = %Nodes
@onready var prestige_bar = %PrestigeBar
@onready var prestige_amount = %PrestigeAmount

var is_spawning := false

func _ready():
	visible = false
	for node: UpgradeNode in upgrade_nodes.get_children():
		node.setup_neighbors()
		node.purchased.connect(_on_upgrade_purchased)
	EventBus.currency_ui_update.connect(_on_currency_changed)
	load_node_levels()
	update_tree()


func _input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("escape"):
		_on_close_pressed()
		get_viewport().set_input_as_handled()
		return
	world.handle_map_input(event)


func show_panel() -> void:
	show()
	world.reset_view(size)
	GameManager.curr_state = GameManager.GameStates.PAUSED
	load_node_levels()
	update_tree()
	play_intro_spawn()


func close() -> void:
	visible = false
	is_spawning = false


func load_node_levels() -> void:
	for node in upgrade_nodes.get_children():
		if node.upgrade != null:
			node.maximum_level = node.upgrade.get_max_level()
			node.current_level = UpgradeManager.get_level(node.upgrade.id)


func update_tree():
	for upgrade_node: UpgradeNode in upgrade_nodes.get_children():
		upgrade_node.update_status()
	update_progress()
	world.queue_redraw()


func update_progress() -> void:
	var bought := 0
	var total := 0
	for upgrade_node in upgrade_nodes.get_children():
		bought += upgrade_node.current_level
		total += upgrade_node.maximum_level
	if total <= 0:
		prestige_bar.value = 0.0
		prestige_amount.text = "0 / 0"
		return
	prestige_bar.max_value = float(total)
	prestige_bar.value = float(bought)
	prestige_amount.text = "%d / %d" % [bought, total]


func play_intro_spawn() -> void:
	if is_spawning:
		return
	is_spawning = true
	var depth_map = traverse_nodes_depth()
	for depth in depth_map.keys():
		if not visible:
			is_spawning = false
			return
		if depth > 0:
			await get_tree().create_timer(0.05 * depth).timeout
		var nodes = depth_map[depth]
		for node: UpgradeNode in nodes:
			Springer.rotate(node, -12)
			Springer.scale(node, 1.3)
	is_spawning = false


func traverse_nodes_depth():
	var total = upgrade_nodes.get_child_count()
	var s = 0
	var queue = []
	var visited = []
	var depth_queue = [0]
	var result = {0: [upgrade_nodes.get_child(0)]}
	visited.resize(total)
	visited.fill(false)
	visited[s] = true
	queue.append(s)
	while not queue.is_empty():
		var curr = queue.pop_front()
		var depth = depth_queue.pop_front()
		var curr_node = upgrade_nodes.get_child(curr)
		for i in total:
			var node = upgrade_nodes.get_child(i)
			if node.node1 == curr_node or node.node2 == curr_node:
				if not visited[i]:
					var new_depth = depth + 1
					visited[i] = true
					queue.append(i)
					depth_queue.append(depth + 1)
					if not result.has(new_depth):
						result[new_depth] = []
					result[new_depth].append(node)
	return result


func _on_upgrade_purchased(_purchased_node) -> void:
	update_tree()


func _on_currency_changed() -> void:
	if visible:
		update_tree()


func _on_close_pressed() -> void:
	var parent_gui := get_parent()
	if parent_gui is GUI:
		parent_gui.close_upgrade_tree()
	else:
		close()
		GameManager.curr_state = GameManager.GameStates.PLAYING
