extends Camera2D
class_name CameraRig
## Camara de zona. Follow/lookahead/punch/shake via CameraFeelProfile.
## Registro: Refs.camera. Desde cualquier lado: Refs.camera.shake(...) o Refs.shake_camera(...).

@export var profile: CameraFeelProfile

var punch_offset: Vector2 = Vector2.ZERO
var lookahead_offset: Vector2 = Vector2.ZERO
var shake_offset: Vector2 = Vector2.ZERO
var is_latched: bool = false
var shake_time_left: float = 0.0
var shake_duration: float = 0.18
var shake_intensity: float = 0.0
var shake_frequency: float = 28.0
var shake_phase: float = 0.0


func _ready() -> void:
	Refs.camera = self
	if profile != null:
		zoom = profile.default_zoom
	# Hijo _ready corre antes que el @onready del Player padre.
	call_deferred("connect_player_drill")


func _exit_tree() -> void:
	if Refs.camera == self:
		Refs.camera = null


func _physics_process(delta: float) -> void:
	if profile == null:
		return
	update_lookahead(delta)
	update_punch(delta)
	update_shake(delta)
	update_zoom(delta)
	offset = lookahead_offset + punch_offset + shake_offset


func connect_player_drill() -> void:
	var player := get_parent() as Player
	if player == null:
		return
	var drill := player.drill_weapon
	if not drill.ore_hit.is_connected(_on_drill_ore_hit):
		drill.ore_hit.connect(_on_drill_ore_hit)


func update_lookahead(delta: float) -> void:
	var target := Vector2.ZERO
	if profile.follow_enabled:
		var player := get_parent() as Player
		if player != null and player.velocity.length() >= profile.min_lookahead_speed:
			target = player.velocity.normalized() * profile.lookahead_distance
	lookahead_offset = lookahead_offset.lerp(target, clampf(profile.lookahead_smoothing * delta, 0.0, 1.0))


func update_punch(delta: float) -> void:
	punch_offset = punch_offset.move_toward(Vector2.ZERO, profile.punch_return_speed * delta)


func update_shake(delta: float) -> void:
	if shake_time_left <= 0.0:
		shake_offset = Vector2.ZERO
		return
	shake_time_left = maxf(shake_time_left - delta, 0.0)
	var falloff := shake_time_left / maxf(shake_duration, 0.001)
	shake_phase += TAU * shake_frequency * delta
	shake_offset = Vector2(sin(shake_phase), cos(shake_phase * 1.37)) * shake_intensity * falloff


func update_zoom(delta: float) -> void:
	var player := get_parent() as Player
	is_latched = player != null and player.drill_weapon.is_drilling()
	var target_zoom: Vector2 = profile.latch_zoom if is_latched else profile.default_zoom
	zoom = zoom.lerp(target_zoom, clampf(profile.zoom_smoothing * delta, 0.0, 1.0))


## Shake omnidireccional. intensity en px de offset, duration en segundos.
func shake(intensity: float = -1.0, duration: float = -1.0, frequency: float = -1.0) -> void:
	if intensity < 0.0:
		intensity = profile.default_shake_intensity if profile != null else 8.0
	if duration < 0.0:
		duration = profile.default_shake_duration if profile != null else 0.18
	if frequency < 0.0:
		frequency = profile.default_shake_frequency if profile != null else 28.0
	shake_intensity = intensity
	shake_duration = maxf(duration, 0.01)
	shake_time_left = shake_duration
	shake_frequency = frequency


## Empuje direccional (drill / impacto). direction se normaliza.
func punch(direction: Vector2, strength: float) -> void:
	apply_punch(strength, direction)


func apply_punch(strength: float, aim: Vector2) -> void:
	if profile == null or strength <= 0.0:
		return
	var dir := aim if aim.length_squared() > 0.01 else Vector2.RIGHT
	punch_offset += -dir.normalized() * strength


func _on_drill_ore_hit(ore: Ore, _damage: float) -> void:
	var player := get_parent() as Player
	if player == null or profile == null:
		return
	var strength: float = profile.chip_punch if ore.is_alive() else profile.oneshot_punch
	apply_punch(strength, player.aim_direction)
