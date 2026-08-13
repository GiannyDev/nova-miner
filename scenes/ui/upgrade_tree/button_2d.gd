@tool
extends Node2D

signal pressed
signal mouse_entered
signal mouse_exited

@export_multiline var button_text := "Button"
@export var disable_after_click := false
@export var disabled := false
@export var normal_color := Color("0071bd")
@export var disabled_color := Color("404040")
@export var border_color := Color("ffffff")
@export var border_width := 0.0
@export var shadow_color := Color("000000", 0.5)
@export var shadow_size := 0.0
@export var shadow_offset := Vector2(2, 2)

@onready var button = $Button
@onready var label = $Button / Label
@onready var juice = $Juice
@onready var hover_sfx = $Hover
@onready var click_sfx = $Click

var should_update_style := false


func _ready():
	if Engine.is_editor_hint():
		return

	var stylebox = button.get_theme_stylebox("normal")
	stylebox.shadow_color = shadow_color
	stylebox.shadow_size = shadow_size
	stylebox.shadow_offset = shadow_offset
	stylebox.border_width_left = border_width
	stylebox.border_width_top = border_width
	stylebox.border_width_right = border_width
	stylebox.border_width_bottom = border_width

	button.add_theme_stylebox_override("hover", stylebox.duplicate())
	button.add_theme_stylebox_override("pressed", stylebox.duplicate())
	button.add_theme_stylebox_override("disabled", stylebox.duplicate())

	update_button_style()


func _process(_delta):
	if Engine.is_editor_hint() or should_update_style:
		update_button_style()

	label.text = button_text
	button.disabled = disabled
	button.position = -button.size / 2


func update_button_style():
	should_update_style = false
	button.get_theme_stylebox("normal").bg_color = normal_color
	button.get_theme_stylebox("hover").bg_color = normal_color.lightened(0.25)
	button.get_theme_stylebox("pressed").bg_color = normal_color.darkened(0.25)
	button.get_theme_stylebox("disabled").bg_color = disabled_color

	button.get_theme_stylebox("normal").border_color = border_color
	button.get_theme_stylebox("hover").border_color = border_color
	button.get_theme_stylebox("pressed").border_color = border_color
	button.get_theme_stylebox("disabled").border_color = border_color


func enable():
	disabled = false


func disable():
	disabled = true


func spawn():
	juice.spawn()


func grab_focus():
	button.grab_focus()


func _on_button_pressed():
	click_sfx.play()
	juice.twist_random()
	juice.jiggle()
	if disable_after_click:
		disable()
	pressed.emit()


func _on_button_mouse_entered():
	hover_sfx.play()
	mouse_entered.emit()


func _on_button_mouse_exited():
	mouse_exited.emit()


func set_normal_color(color):
	normal_color = color
	should_update_style = true


func set_disabled_color(color):
	disabled_color = color
	should_update_style = true


func set_border_color(color):
	border_color = color
	should_update_style = true
