extends Control
## Defines the CharacterStandee script.
class_name CharacterStandee

signal standee_selected(character_index: int)

const INK: Color = Color(0.12, 0.10, 0.08)
const HP_GREEN: Color = Color(0.50, 0.82, 0.25)
const STATUS_EFFECT_ICON_SCENE: PackedScene = preload("res://scenes/ui/StatusEffectIcon.tscn")

@onready var hp_bar: ProgressBar = $Content/HpWrap/HpBar
@onready var hp_label: Label = $Content/HpWrap/HpLabel
@onready var portrait: CharacterMotion = $Content/Portrait
@onready var shield_visual: ShieldVisual = $ShieldVisual
@onready var effect_container: HBoxContainer = $EffectContainer
@onready var hit_button: PortraitHitButton = $Content/Portrait/VisualRoot/HitButton
@onready var target_highlight: Panel = $Content/Portrait/VisualRoot/HitButton/TargetHighlight

var character_index: int = -1
var bound_character: CharacterData


## Makes only the body's child button clickable; health and status displays remain passive.
func _ready() -> void:
	hit_button.pressed.connect(_on_pressed)
	hit_button.add_theme_stylebox_override("hover", _style(Color(0.72, 0.86, 1.0, 0.22), 8, 2))
	hit_button.add_theme_stylebox_override("pressed", _style(Color(0.72, 0.86, 1.0, 0.35), 8, 2))
	hp_bar.add_theme_stylebox_override("background", _style(Color(0.40, 0.34, 0.27), 12, 2))
	hp_bar.add_theme_stylebox_override("fill", _style(HP_GREEN, 12, 1))
	_apply_target_highlight_style()


## Refreshes values without replacing the character's active animation.
func setup(character: CharacterData, index: int, selected: bool, target_highlighted: bool) -> void:
	bound_character = character
	character_index = index
	hit_button.disabled = not character.is_alive()

	var character_alpha: float = 1.0
	if not character.is_alive():
		character_alpha = 0.35
	elif character.has_acted:
		character_alpha = 0.52
	modulate = Color(1, 1, 1, character_alpha)

	var normal_color: Color = Color(0, 0, 0, 0)
	var normal_border: int = 0
	if target_highlighted:
		normal_color = Color(0.58, 0.96, 0.62, 0.34)
		normal_border = 3
	elif selected:
		normal_color = Color(0.72, 0.86, 1.0, 0.23)
		normal_border = 2
	hit_button.add_theme_stylebox_override("normal", _style(normal_color, 8, normal_border))

	hp_bar.max_value = character.max_hp
	hp_bar.value = character.current_hp
	hp_label.text = "%d / %d" % [character.current_hp, character.max_hp]
	portrait.setup(character.battle_animation_path, character.portrait_path, character.is_alive())
	shield_visual.setup(character.current_shield, character.turn_damage_reduction)
	_refresh_effects(character.active_effects)
	target_highlight.visible = target_highlighted


## Starts an attack or hurt sequence and reports its playback duration.
func play_action(animation_name: StringName) -> float:
	return portrait.play_action(animation_name)


## Gives selection feedback without moving the HP bar or standee slot.
func play_selection_jump() -> void:
	portrait.play_selection_jump()


## Shares the body alpha mask with card targeting instead of the full standee rectangle.
func contains_global_point(mouse_global_position: Vector2) -> bool:
	return hit_button.contains_global_point(mouse_global_position)


func _refresh_effects(effects: Array[StatusEffectData]) -> void:
	for child: Node in effect_container.get_children():
		child.queue_free()
	for effect: StatusEffectData in effects:
		if not effect.is_active():
			continue
		var effect_icon: StatusEffectIcon = STATUS_EFFECT_ICON_SCENE.instantiate() as StatusEffectIcon
		effect_container.add_child(effect_icon)
		effect_icon.setup(effect)


func _on_pressed() -> void:
	if character_index >= 0:
		standee_selected.emit(character_index)


func _apply_target_highlight_style() -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.50, 1.0, 0.52, 0.30)
	style.border_color = Color(0.36, 1.0, 0.42)
	style.border_width_left = 5
	style.border_width_right = 5
	style.border_width_top = 5
	style.border_width_bottom = 5
	style.corner_radius_top_left = 12
	style.corner_radius_top_right = 12
	style.corner_radius_bottom_left = 12
	style.corner_radius_bottom_right = 12
	style.shadow_color = Color(0.36, 1.0, 0.42, 0.45)
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
