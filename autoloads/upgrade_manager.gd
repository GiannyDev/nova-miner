## Aplica upgrades permanentes del arbol al StatBlock del jugador.

extends Node

var upgrade_data: UpgradeData = UpgradeData.new()


func _ready() -> void:
	pass


func add_upgrade(upgrade_type: UpgradeData.UpgradeType, upgrade: Resource) -> void:
	var upgrade_snapshot: Resource = upgrade.duplicate()
	upgrade_data.permanent_upgrades[upgrade_type].append(upgrade_snapshot)


func apply_stats_to_player() -> void:
	apply_stats_to_new_object(UpgradeData.UpgradeType.PLAYER, GameManager.player_stats)
	apply_stats_to_new_object(UpgradeData.UpgradeType.HELPERS, GameManager.player_stats)


func apply_stats_to_new_object(upgrade_type: UpgradeData.UpgradeType, stats: StatBlock) -> void:
	for upgrade in upgrade_data.permanent_upgrades[upgrade_type]:
		if upgrade is StatUpgrade:
			upgrade.apply_upgrade(stats)
