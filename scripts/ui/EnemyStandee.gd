extends Button
## Defines the EnemyStandee script.
class_name EnemyStandee

signal standee_selected(enemy_index: int)

const INK: Color = Color(0.12, 0.10, 0.08)
const HP_RED: Color = Color(0.93, 0.25, 0.20)
const STATUS_EFFECT_ICON_SCENE: PackedScene = preload("res://scenes/ui/StatusEffectIcon.tscn")

@onready var hp_bar: ProgressBar = $Content/HpWrap/HpBar
@onready var hp_label: Label = $Content/HpWrap/HpLabel
@onready var portrait: TextureRect = $Content/Portrait
@onready var shield_visual: ShieldVisual = $ShieldVisual
@onready var effect_container: HBoxContainer = $EffectContainer
@onready var target_highlight: Panel = $TargetHighlight

var enemy_index: int = -1


func _ready() -> void:
	pressed.connect(_on_pressed)
	add_theme_stylebox_override("hover", _style(Color(1.0, 0.82, 0.74, 0.22), 8, 2))
	add_theme_stylebox_override("pressed", _style(Color(1.0, 0.82, 0.74, 0.35), 8, 2))
	hp_bar.add_theme_stylebox_override("background", _style(Color(0.40, 0.34, 0.27), 12, 2))
	hp_bar.add_theme_stylebox_override("fill", _style(HP_RED, 12, 1))
	_apply_target_highlight_style()


func setup(enemy: EnemyData, index: int, selected: bool, target_highlighted: bool) -> void:
	enemy_index = index
	disabled = not enemy.is_alive()
	modulate = Color(1, 1, 1, 1.0 if enemy.is_alive() else 0.30)

	var normal_color: Color = Color(0, 0, 0, 0)
	var normal_border: int = 0
	if target_highlighted:
		normal_color = Color(1.0, 0.75, 0.42, 0.34)
		normal_border = 3
	elif selected:
		normal_color = Color(1.0, 0.82, 0.74, 0.23)
		normal_border = 2
	add_theme_stylebox_override("normal", _style(normal_color, 8, normal_border))

	hp_bar.max_value = enemy.max_hp
	hp_bar.value = enemy.current_hp
	hp_label.text = "%d / %d" % [enemy.current_hp, enemy.max_hp]
	portrait.texture = load(enemy.portrait_path) as Texture2D
	shield_visual.setup(enemy.current_shield, enemy.damage_reduction)
	_refresh_effects(enemy)
	target_highlight.visible = target_highlighted


func _refresh_effects(enemy: EnemyData) -> void:
	for child: Node in effect_container.get_children():
		child.queue_free()
	var effects: Array[StatusEffectData] = enemy.active_effects.duplicate()
	var target_lock_effect: StatusEffectData = _create_target_lock_effect(enemy)
	if target_lock_effect != null:
		effects.append(target_lock_effect)
	for effect: StatusEffectData in effects:
		if not effect.is_active():
			continue
		var effect_icon: StatusEffectIcon = STATUS_EFFECT_ICON_SCENE.instantiate() as StatusEffectIcon
		effect_container.add_child(effect_icon)
		effect_icon.setup(effect)


func _create_target_lock_effect(enemy: EnemyData) -> StatusEffectData:
	if not enemy.is_charging():
		return null
	var effect: StatusEffectData = EffectDatabase.create_effect(
		"target_lock",
		0.0,
		enemy.charge_remaining_turns,
		"%s::%s" % [enemy.id, enemy.charge_ability_id],
		"ENEMY_ABILITY_NIAN_CHARGE_ATTACK"
	)
	if effect == null:
		return null
	effect.value_text = "EFFECT_TARGET_LOCK_VALUE"
	effect.detail_text = enemy.charge_target_name
	effect.overlay_icon_path = enemy.charge_target_portrait_path
	return effect


func _on_pressed() -> void:
	if enemy_index >= 0:
		standee_selected.emit(enemy_index)


func _apply_target_highlight_style() -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(1.0, 0.72, 0.32, 0.30)
	style.border_color = Color(1.0, 0.58, 0.18)
	style.border_width_left = 5
	style.border_width_right = 5
	style.border_width_top = 5
	style.border_width_bottom = 5
	style.corner_radius_top_left = 12
	style.corner_radius_top_right = 12
	style.corner_radius_bottom_left = 12
	style.corner_radius_bottom_right = 12
	style.shadow_color = Color(1.0, 0.58, 0.18, 0.45)
	style.shadow_size = 12
	target_highlight.add_theme_stylebox_override("panel", style)


func _style(color: Color, radius: int, border_width: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.corner_radius_top_left = radius
	style.corner_radius_top_right = radius
	style.corner_radius_bottom_left = radius
	style.corner_radius_bottom_right = radius
	style.border_width_left = border_width
	style.border_width_right = border_width
	style.border_width_top = border_width
	style.border_width_bottom = border_width
	style.border_color = Color(0.13, 0.10, 0.08)
	style.shadow_color = Color(0, 0, 0, 0.20)
	style.shadow_size = 5
	return style
