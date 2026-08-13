extends UpgradePrice
class_name UpgradePriceLinear

@export var base_cost := 10
@export var rate_growth := 5

func calculate(i: int) -> int:
	return base_cost + rate_growth * i
