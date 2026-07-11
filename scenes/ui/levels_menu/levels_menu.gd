extends Control
class_name LevelMenu

func show_panel() -> void:
	show()
	GameManager.curr_state = GameManager.GameStates.PAUSED

func hide_panel() -> void:
	hide()
	GameManager.curr_state = GameManager.GameStates.PLAYING
