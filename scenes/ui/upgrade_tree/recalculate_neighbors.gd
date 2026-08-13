@tool
extends Node2D

@export var recalculate := false: set = set_recalculate


func recalculate_neighbors():
	for node1 in get_children():
		node1.left_neighbor = null
		node1.top_neighbor = null
		node1.right_neighbor = null
		node1.bottom_neighbor = null

		for node2 in get_children():
			if node1 != node2:
				var diff = node2.global_position - node1.global_position
				if diff == 75.0 * Vector2.LEFT:
					node1.left_neighbor = node2
				elif diff == 75.0 * Vector2.UP:
					node1.top_neighbor = node2
				elif diff == 75.0 * Vector2.RIGHT:
					node1.right_neighbor = node2
				elif diff == 75.0 * Vector2.DOWN:
					node1.bottom_neighbor = node2


func set_recalculate(value):
	if value:
		recalculate_neighbors()
