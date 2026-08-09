extends TextureRect
class_name PerkMineDisplay
## Icono de perk en la mina. Hover → spring + tooltip via EventBus.

var perk_data: PerkData


## Aplica data al icono (texture) para el HUD de perks.
func setup(data: PerkData) -> void:
	perk_data = data
	if data != null and data.icon != null:
		texture = data.icon


func _on_mouse_entered() -> void:
	pivot_offset = size / 2.0
	Springer.rotate(self, 3)
	EventBus.on_perk_mine_display_tooltip.emit(self)


func _on_mouse_exited() -> void:
	EventBus.on_perk_mine_display_tooltip_hide.emit()
