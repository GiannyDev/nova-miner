extends Node

var gui: GUI
var player: Player
var mine_zone: MineZone
var inventory: Inventory
var camera: CameraRig

const SETTINGS_MENU = preload("uid://c3cv87vswpk7l")

const ORE_SCENE = preload("res://scenes/ore/ore.tscn")
const ORE_DROP_SCENE = preload("res://scenes/ore/ore_drop.tscn")
const REFINED_ORE_SCENE = preload("res://scenes/ore/refined_ore.tscn")
const DAMAGE_TEXT_SCENE = preload("res://scenes/ui/damage_text/damage_text.tscn")

const PERK_MINE_DISPLAY_SCENE = preload("res://scenes/ui/perks/perk_mine_display.tscn")


## Shake omnidireccional. Atajo de Refs.camera.shake(...). No-op si no hay camara de zona.
func shake_camera(intensity: float = -1.0, duration: float = -1.0, frequency: float = -1.0) -> void:
	if camera == null:
		return
	camera.shake(intensity, duration, frequency)


## Empuje direccional (impacto / drill).
func punch_camera(direction: Vector2, strength: float) -> void:
	if camera == null:
		return
	camera.punch(direction, strength)


## Shake de bomba. Atajo de Refs.camera.shake_bomb().
func shake_bomb() -> void:
	if camera == null:
		return
	camera.shake_bomb()
