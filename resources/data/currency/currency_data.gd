extends Resource
class_name CurrencyData

enum CurrencyType { MONEY, SCREW }

@export var currency_amount: Dictionary = {
	CurrencyType.MONEY: 0,
	CurrencyType.SCREW: 0,
}
