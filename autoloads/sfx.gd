extends Node

var sound_dict: Dictionary[int, Resource] = {
	Sound.BUTTON_CLICK: preload("uid://brbhb2vqy5c61"),
	Sound.BUTTON_HOVER: preload("uid://chkex35lvyuc0"),
	Sound.UI_PANEL_POP: preload("uid://cr28rsmya7mh1")
}

var _is_ready: bool = false
var cooldown_dict: Dictionary = {}

var players_short: Array = []
var short_index: int = 0
var base_volume: float

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	for _i in range(50):
		var audio_player = AudioStreamPlayer.new()
		audio_player.volume_db = base_volume
		audio_player.process_mode = Node.PROCESS_MODE_ALWAYS
		audio_player.bus = "SFX"
		get_tree().root.call_deferred("add_child", audio_player)
		players_short.append(audio_player)
	for key in sound_dict:
		cooldown_dict[key] = 0
	await get_tree().process_frame
	_is_ready = true


func _physics_process(_delta):
	for key in cooldown_dict:
		if cooldown_dict[key] > 0:
			cooldown_dict[key] -= 1


func play(sound: Variant, rand_pitch_range: float = 0.05, volume_delta: float = 0.0, pitch_delta: float = 0.0, cooldown_frames: int = 1) -> void:
	if not _is_ready:
		return

	if sound is AudioStream:
		_play_stream(sound as AudioStream, rand_pitch_range, volume_delta, pitch_delta)
		return

	if typeof(sound) != TYPE_INT:
		push_warning("SFX.play: se esperaba Sound id (int) o AudioStream")
		return

	var sound_id: int = sound
	if cooldown_dict.get(sound_id, 0) > 0:
		return

	var stream = sound_dict.get(sound_id)
	if stream == null:
		push_warning("SFX.play: sound id %s no registrado" % sound_id)
		return
	if stream is Array:
		stream = stream.pick_random()

	_play_stream(stream as AudioStream, rand_pitch_range, volume_delta, pitch_delta)
	cooldown_dict[sound_id] = cooldown_frames


func _play_stream(stream: AudioStream, rand_pitch_range: float = 0.05, volume_delta: float = 0.0, pitch_delta: float = 0.0) -> void:
	if stream == null or players_short.is_empty():
		return
	var source := players_short[short_index] as AudioStreamPlayer
	source.playing = false
	source.stream = stream
	source.pitch_scale = randf_range(1.0 - rand_pitch_range, 1.0 + rand_pitch_range) + pitch_delta
	source.play(0.0)
	short_index = (short_index + 1) % players_short.size()


func create_source(parent: Node2D, sound: int, rand_pitch_range: float = 0.08, volume_delta: float = 0.0) -> AudioStreamPlayer:
	var source = AudioStreamPlayer.new()
	parent.add_child(source)
	source.playing = false
	source.stream = sound_dict[sound]
	source.pitch_scale = randf_range(1.0 - rand_pitch_range, 1.0 + rand_pitch_range)
	source.bus = "SFX"
	
	return source
