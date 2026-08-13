@tool
extends Node2D

@export_multiline var title: String
@export_multiline var description: String
@export var price: String

@onready var panel = $Panel
@onready var title_label: Label = %Title
@onready var separator = %Separator
@onready var desc_label = %Description
@onready var juice: Juice2D = $Juice

@onready var starting_pos := global_position

var is_open := false
var opacity_spring: DampedSpring1D


func _ready():
	if not Engine.is_editor_hint():
		opacity_spring = DampedSpring1D.new(1.0, 25.0).rest_at(0.0)


func _physics_process(delta):
	if opacity_spring:
		opacity_spring.update(delta)


func _process(_delta):
	if visible:
		if not Engine.is_editor_hint():
			separator.visible = not description.is_empty()
			modulate.a = opacity_spring.position
		panel.position = (-panel.size / 2) + Vector2.UP * 20
		title_label.text = title
		desc_label.text = description


func open():
	is_open = true
	juice.twist()
	juice.jiggle(-4.0)
	opacity_spring.rest_at(1.0)
	opacity_spring.position = 0.5


func close():
	is_open = false
	juice.twist(0.0, 1.0)
	juice.jiggle(1.0)
	opacity_spring.rest_at(0.0)


func squash():
	juice.squash(1.0)
