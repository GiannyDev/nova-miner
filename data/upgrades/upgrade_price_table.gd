extends UpgradePrice
class_name UpgradePriceTable

@export var table: Array[int]

func calculate(i: int) -> int:
	if table.is_empty(): return 0
	return table[clamp(i, 0, table.size() - 1)]
