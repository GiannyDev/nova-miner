extends Button
class_name DrillUpgradeButton

@export var upgrade_type: WeaponData.WeaponUpgradeType

@onready var stat_name: RichTextLabel = %StatName
@onready var stat_value: RichTextLabel = %StatValue
@onready var price_label: RichTextLabel = %PriceLabel

func _ready() -> void:
	stat_name.text = WeaponData.get_upgrade_name(upgrade_type)


func _on_pressed() -> void:
	Springer.scale(self, -0.05)


func _on_mouse_entered() -> void:
	pivot_offset = size / 2
	Springer.rotate(self, 1.5)
