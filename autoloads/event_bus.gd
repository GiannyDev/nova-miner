extends Node

signal upgrade_purchased
signal currency_ui_update


func emit_upgrade_purchased() -> void:
	upgrade_purchased.emit()


func emit_currency_ui_update() -> void:
	currency_ui_update.emit()
