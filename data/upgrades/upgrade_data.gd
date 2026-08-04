extends Resource
class_name UpgradeData

enum UpgradeType { PLAYER, TOOLS, ORES, HELPERS, PROCS }

@export var permanent_upgrades: Dictionary = {
	UpgradeType.PLAYER: [],
	UpgradeType.TOOLS: [],
	UpgradeType.ORES: [],
	UpgradeType.HELPERS: [],
	UpgradeType.PROCS: [],
}
