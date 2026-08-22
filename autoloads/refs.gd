extends Node

var gui: GUI
var player: Player
var mine_zone: MineZone
var inventory: Inventory
var camera: CameraRig

const ORE_SCENE = preload("res://scenes/ore/ore.tscn")
const ORE_DROP_SCENE = preload("res://scenes/ore/ore_drop.tscn")
const REFINED_ORE_SCENE = preload("res://scenes/ore/refined_ore.tscn")
const DAMAGE_TEXT_SCENE = preload("res://scenes/ui/damage_text/damage_text.tscn")

const PERK_MINE_DISPLAY_SCENE = preload("res://scenes/ui/perks/perk_mine_display.tscn")


## Shake omnidireccional. Atajo de Refs.camera.shake(...).
func shake_camera(intensity: float, duration: float = 0.18, frequency: float = 28.0) -> void:
	camera.shake(intensity, duration, frequency)


## Empuje direccional (impacto / drill).
func punch_camera(direction: Vector2, strength: float) -> void:
	camera.punch(direction, strength)
