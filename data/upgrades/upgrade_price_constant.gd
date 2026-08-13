extends UpgradePrice
class_name UpgradePriceConstant

@export var fixed_cost: int = 10

func calculate(_i: int) -> int:
	return fixed_cost
