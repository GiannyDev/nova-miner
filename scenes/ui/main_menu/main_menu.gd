extends Control
class_name MainMenu

@export_category("Dev Settings")
@export var is_demo: bool = true
@export var use_cheats: bool = true
@export var discord_link: String

@export_category("References")
@export var buttons: Array[Button]

@onready var settings_menu: SettingsMenu = $SettingsMenu
@onready var collection_menu: CollectionMenu = $CollectionMenu

func _ready() -> void:
	for btn: Button in buttons:
		btn.mouse_entered.connect(_on_btn_mouse_entered.bind(btn))


func _on_btn_mouse_entered(btn: Button) -> void:
	pass


func _on_play_button_pressed() -> void:
	await Transition.fade_out(1.0)
	get_tree().change_scene_to_file("res://scenes/zones/base_zone/base_zone.tscn")
	await Transition.fade_in(1.0)


func _on_collection_button_pressed() -> void:
	pass # Replace with function body.


func _on_settings_option_pressed() -> void:
	settings_menu.show()


func _on_wishlist_button_pressed() -> void:
	## TODO: Open Discord Server with Link
	pass # Replace with function body.


func _on_quit_button_pressed() -> void:
	## TODO: Add Save Game
	get_tree().quit()
