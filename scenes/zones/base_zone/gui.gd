extends CanvasLayer
class_name GUI

@onready var upgrade_tree: UpgradeTree = $UpgradeTree
@onready var weapon_shop: WeaponShop = $WeaponShop
@onready var settings_menu: SettingsMenu = $SettingsMenu
@onready var levels_menu: LevelMenu = $LevelsMenu

func _ready() -> void:
	pass


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("escape"):
		if levels_menu.visible:
			levels_menu.hide_panel()

func open_upgrade_tree() -> void:
	upgrade_tree.open()
	GameManager.curr_state = GameManager.GameStates.PAUSED


func close_upgrade_tree() -> void:
	upgrade_tree.close()
	GameManager.curr_state = GameManager.GameStates.PLAYING


func is_upgrade_tree_open() -> bool:
	return upgrade_tree.visible


func open_weapon_shop() -> void:
	weapon_shop.show_panel()


func close_weapon_shop() -> void:
	weapon_shop.hide_panel()


func is_weapon_shop_open() -> bool:
	return weapon_shop.visible
