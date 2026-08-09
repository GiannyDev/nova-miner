extends Resource
class_name JuicePreset
## Parametros tunables para animaciones UI reutilizables (ShellDiver, Forager, count-up).

@export_group("ShellDiver")
@export var shell_slide_offset: float = 48.0
@export var shell_rotation_deg: float = -10.0
@export var shell_fade_duration: float = 0.35
@export var shell_slide_duration: float = 0.45
@export var shell_rotation_duration: float = 0.5
@export var shell_spring_rotate: float = 14.0

@export_group("Forager")
@export var forager_pop_duration: float = 0.35
@export var forager_fade_duration: float = 0.2
@export var forager_spring_scale: float = 0.18

@export_group("Count Up")
@export var count_up_duration: float = 0.55
@export var count_up_trans: Tween.TransitionType = Tween.TRANS_QUART
@export var count_up_ease: Tween.EaseType = Tween.EASE_OUT

@export_group("Stagger")
@export var stagger_delay: float = 0.1

@export_group("Slide In (HUD cascade)")
@export var slide_in_offset: float = 80.0
@export var slide_in_duration: float = 0.4
@export var slide_in_fade_duration: float = 0.28
@export var slide_in_trans: Tween.TransitionType = Tween.TRANS_QUART
@export var slide_in_ease: Tween.EaseType = Tween.EASE_OUT
