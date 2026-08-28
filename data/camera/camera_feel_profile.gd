extends Resource
class_name CameraFeelProfile
## Tuneo de follow / punch / zoom. Un .tres por zona (mina vs hub).

@export_group("Follow")
## Si false, la camara no persigue (hub fijo).
@export var follow_enabled: bool = true
## Distancia extra hacia donde se mueve el player.
@export var lookahead_distance: float = 90.0
@export var lookahead_smoothing: float = 6.0
@export var min_lookahead_speed: float = 40.0

@export_group("Zoom")
@export var default_zoom: Vector2 = Vector2(0.55, 0.55)
@export var latch_zoom: Vector2 = Vector2(0.62, 0.62)
@export var zoom_smoothing: float = 8.0

@export_group("Punch")
## Recoil al chip multi-hit.
@export var chip_punch: float = 5.0
## Recoil al oneshot (mas corto, mas marcado).
@export var oneshot_punch: float = 12.0
@export var punch_return_speed: float = 55.0

@export_group("Shake")
@export var default_shake_intensity: float = 8.0
@export var default_shake_duration: float = 0.18
@export var default_shake_frequency: float = 28.0
## Shake al explotar una bomba. Desde cualquier lado: Refs.camera.shake(...) o shake_bomb().
@export var bomb_shake_intensity: float = 18.0
@export var bomb_shake_duration: float = 0.24
@export var bomb_shake_frequency: float = 34.0
