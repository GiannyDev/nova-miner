extends Node
class_name MiningAudio
## Pitch ladder de minado. SFX solo reproduce; este nodo posee el combo.
## Cada chip sube el tono; al romper o al dejar de picar, vuelve al baseline.

@export var chip_sound: int = Sound.PLAYER_DRILL
@export var break_sound: int = Sound.ORE_BREAK
@export var pitch_step: float = 0.07
@export var pitch_max: float = 0.5
@export var mineral_bonus: float = 0.16
@export var break_bonus: float = 0.28
@export var reset_idle: float = 0.4
@export var rand_pitch: float = 0.07
@export var chip_volume_db: float = -4.0
@export var break_volume_db: float = -2.0

var combo_pitch: float = 0.0
var idle_timer: float = 0.0
var last_chip_frame: int = -1
var last_break_frame: int = -1


func _process(delta: float) -> void:
	if combo_pitch <= 0.0:
		return
	idle_timer += delta
	if idle_timer >= reset_idle:
		combo_pitch = 0.0


## Un golpe que no mata: chip + sube combo. Si el bloque ya murio, solo break.
func notify_hit(ore: Ore) -> void:
	if ore == null:
		return
	idle_timer = 0.0
	if not ore.is_alive():
		notify_break(ore)
		return
	var frame := Engine.get_physics_frames()
	if frame == last_chip_frame:
		return
	last_chip_frame = frame
	var pitch := combo_pitch
	if ore.is_mineral():
		pitch += mineral_bonus
	SFX.play(chip_sound, rand_pitch, chip_volume_db, pitch, 0)
	combo_pitch = minf(combo_pitch + pitch_step, pitch_max)


## Bloque destruido: one-shot mas agudo y reset del combo.
func notify_break(ore: Ore) -> void:
	idle_timer = 0.0
	var frame := Engine.get_physics_frames()
	if frame == last_break_frame:
		combo_pitch = 0.0
		return
	last_break_frame = frame
	var pitch := combo_pitch + break_bonus
	if ore != null and ore.is_mineral():
		pitch += mineral_bonus * 0.5
	SFX.play(break_sound, rand_pitch, break_volume_db, pitch, 0)
	combo_pitch = 0.0
