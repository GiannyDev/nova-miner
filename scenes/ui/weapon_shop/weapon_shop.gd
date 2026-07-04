extends Control
class_name WeaponShop

@export var weapons: Array[WeaponData] = []
@export var anim_sequence: Array[Control]

@onready var weapon_scroll_container: ScrollContainer = %WeaponScrollContainer
@onready var weapon_image_container: HBoxContainer = %WeaponImageContainer
@onready var selection_frame: Panel = %SelectionFrame
@onready var prev_weapon_button: Button = %PrevWeaponButton
@onready var select_weapon_button: Button = %SelectWeaponButton
@onready var next_weapon_button: Button = %NextWeaponButton

const SLOT_WIDTH := 280.0
const VISIBLE_SLOT_COUNT := 3
const SCROLL_DURATION := 0.3

var current_weapon_index: int = 0
var weapon_tween: Tween
var weapons_built: bool = false


func _ready() -> void:
	visible = false


func show_panel() -> void:
	show()
	GameManager.curr_state = GameManager.GameStates.PAUSED
	ensure_weapons()
	if not weapons_built:
		setup_weapons()
		weapons_built = true
	GameManager.animate_panel_open(anim_sequence)
	call_deferred("scroll_to_weapon", find_equipped_index(), false)


func hide_panel() -> void:
	hide()
	GameManager.curr_state = GameManager.GameStates.PLAYING


func ensure_weapons() -> void:
	if not weapons.is_empty():
		return
	weapons = [
		load("res://resources/data/weapons/laser_basic.tres") as WeaponData,
		load("res://resources/data/weapons/laser_pulse.tres") as WeaponData,
		load("res://resources/data/weapons/laser_beam.tres") as WeaponData,
		load("res://resources/data/weapons/laser_split.tres") as WeaponData,
		load("res://resources/data/weapons/laser_chaos.tres") as WeaponData,
	]


func setup_weapons() -> void:
	add_spacer()

	for weapon in weapons:
		var slot := CenterContainer.new()
		slot.custom_minimum_size = Vector2(SLOT_WIDTH, SLOT_WIDTH)
		slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		weapon_image_container.add_child(slot)

		var icon := TextureRect.new()
		icon.texture = weapon.sprite
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.custom_minimum_size = Vector2(SLOT_WIDTH * 0.7, SLOT_WIDTH * 0.7)
		icon.pivot_offset = icon.custom_minimum_size / 2.0
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE

		if not is_weapon_unlocked(weapon):
			icon.self_modulate = Color(0, 0, 0, 1)

		slot.add_child(icon)

	add_spacer()


func scroll_to_weapon(index: int, animate: bool = true) -> void:
	if weapons.is_empty():
		return

	current_weapon_index = clampi(index, 0, weapons.size() - 1)
	var target_scroll := get_target_scroll(current_weapon_index)

	if weapon_tween:
		weapon_tween.kill()

	if animate:
		weapon_tween = create_tween().set_parallel(true)
		weapon_tween.tween_property(weapon_scroll_container, "scroll_horizontal", target_scroll, SCROLL_DURATION)\
			.set_trans(Tween.TRANS_QUINT)\
			.set_ease(Tween.EASE_OUT)
	else:
		weapon_scroll_container.scroll_horizontal = target_scroll

	for i in range(weapons.size()):
		var sector := weapon_image_container.get_child(i + 1)
		var icon := sector.get_child(0) as TextureRect

		var target_scale := Vector2(1, 1)
		var target_modulate := Color(0.5, 0.5, 0.5, 1.0)

		if i == current_weapon_index:
			target_scale = Vector2(1.4, 1.4)
			target_modulate = Color(1, 1, 1, 1)
			sector.z_index = 1
		else:
			sector.z_index = 0

		if not is_weapon_unlocked(weapons[i]):
			target_modulate = Color(0, 0, 0, 1) if i != current_weapon_index else Color(0.35, 0.35, 0.35, 1)

		if animate and weapon_tween:
			weapon_tween.tween_property(icon, "scale", target_scale, SCROLL_DURATION + 0.1)
			weapon_tween.tween_property(icon, "modulate", target_modulate, SCROLL_DURATION + 0.1)
		else:
			icon.scale = target_scale
			icon.modulate = target_modulate

	update_select_button()


func get_current_weapon() -> WeaponData:
	if weapons.is_empty():
		return null
	return weapons[current_weapon_index]


func is_weapon_unlocked(weapon: WeaponData) -> bool:
	if weapon == null:
		return false
	return GameManager.unlocked_weapon_ids.has(weapon.weapon_id)


func find_equipped_index() -> int:
	for i in range(weapons.size()):
		if weapons[i].weapon_id == GameManager.equipped_weapon_id:
			return i
	return 0


func get_target_scroll(index: int) -> float:
	var slot_center_x := SLOT_WIDTH + index * SLOT_WIDTH + SLOT_WIDTH * 0.5
	var viewport_width := weapon_scroll_container.size.x
	if viewport_width <= 0.0:
		viewport_width = SLOT_WIDTH * VISIBLE_SLOT_COUNT
	var max_scroll := maxf(weapon_image_container.size.x - viewport_width, 0.0)
	return clampf(slot_center_x - viewport_width * 0.5, 0.0, max_scroll)


func add_spacer() -> void:
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(SLOT_WIDTH, 0.0)
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	weapon_image_container.add_child(spacer)


func update_select_button() -> void:
	var weapon := get_current_weapon()
	if weapon == null:
		select_weapon_button.disabled = true
		select_weapon_button.text = "SELECT"
		return

	if not is_weapon_unlocked(weapon):
		select_weapon_button.text = "LOCKED"
		select_weapon_button.disabled = true
	elif weapon.weapon_id == GameManager.equipped_weapon_id:
		select_weapon_button.text = "EQUIPPED"
		select_weapon_button.disabled = true
	else:
		select_weapon_button.text = "EQUIP"
		select_weapon_button.disabled = false


func equip_current_weapon() -> void:
	var weapon := get_current_weapon()
	if weapon == null or not is_weapon_unlocked(weapon):
		return

	GameManager.equipped_weapon_id = weapon.weapon_id
	update_select_button()


func _on_prev_weapon_button_pressed() -> void:
	if weapons.is_empty():
		return
	var count := weapons.size()
	current_weapon_index = (current_weapon_index - 1 + count) % count
	scroll_to_weapon(current_weapon_index)


func _on_next_weapon_button_pressed() -> void:
	if weapons.is_empty():
		return
	var count := weapons.size()
	current_weapon_index = (current_weapon_index + 1) % count
	scroll_to_weapon(current_weapon_index)


func _on_select_weapon_button_pressed() -> void:
	equip_current_weapon()


func _on_close_button_pressed() -> void:
	var parent_gui := get_parent()
	if parent_gui is GUI:
		parent_gui.close_weapon_shop()
	else:
		hide_panel()
