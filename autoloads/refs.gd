extends Node

var player: Player
var gui: GUI
var inventory: Inventory
var camera: CameraRig

const ORE_SCENE = preload("uid://dcuuf1m1b62jv")
const ORE_DROP_SCENE = preload("uid://behv72lanuvpp")
const REFINED_ORE_SCENE = preload("uid://dkkjgq0b3f1vw")
const DAMAGE_TEXT_SCENE = preload("res://scenes/ui/damage_text/damage_text.tscn")

const PERK_MINE_DISPLAY_SCENE = preload("uid://csmcrehd0wad2")


## Shake omnidireccional. Atajo de Refs.camera.shake(...).
func shake_camera(intensity: float, duration: float = 0.18, frequency: float = 28.0) -> void:
	camera.shake(intensity, duration, frequency)


## Empuje direccional (impacto / drill).
func punch_camera(direction: Vector2, strength: float) -> void:
	camera.punch(direction, strength)
