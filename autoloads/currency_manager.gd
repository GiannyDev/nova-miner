## Gestiona moneda persistente y operaciones de compra del UpgradeTree.

extends Node

var currency_data: CurrencyData = CurrencyData.new()


func _ready() -> void:
	currency_data.currency_amount[CurrencyData.CurrencyType.MONEY] = 500


func add_currency(currency_type: CurrencyData.CurrencyType, amount: int) -> void:
	currency_data.currency_amount[currency_type] += amount
	EventBus.emit_currency_ui_update()


func remove_currency(currency_type: CurrencyData.CurrencyType, amount: int) -> void:
	currency_data.currency_amount[currency_type] -= amount
	EventBus.emit_currency_ui_update()


func can_afford(currency_type: CurrencyData.CurrencyType, amount: int) -> bool:
	return currency_data.currency_amount.get(currency_type, 0) >= amount
