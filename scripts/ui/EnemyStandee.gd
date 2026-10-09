extends Control
## Defines the EnemyStandee script.
class_name EnemyStandee

signal standee_selected(enemy_index: int)

const INK: Color = Color(0.12, 0.10, 0.08)
const HP_RED: Color = Color(0.93, 0.25, 0.20)
const STATUS_EFFECT_ICON_SCENE: PackedScene = preload("res://scenes/ui/StatusEffectIcon.tscn")

@onready var hp_bar: ProgressBar = $Content/HpWrap/HpBar
@onready var hp_label: Label = $Content/HpWrap/HpLabel
@onready var portrait: TextureRect = $Content/Portrait/VisualRoot/StaticPortrait
@onready var shield_visual: ShieldVisual = $ShieldVisual
@onready var effect_container: HBoxContainer = $EffectContainer
@onready var hit_button: PortraitHitButton = $Content/Portrait/VisualRoot/HitButton
@onready var target_highlight: Panel = $Content/Portrait/VisualRoot/HitButton/TargetHighlight
@onready var visual_root: Control = $Content/Portrait/VisualRoot
@onready var attack_sprite: AnimatedSprite2D = $Content/Portrait/VisualRoot/AttackOrigin/AttackSprite
@onready var attack_animation: AnimationPlayer = $AttackAnimation
@onready var motion: CharacterMotion = $Content/Portrait/VisualRoot/Motion
@onready var magic_ambient: AnimatedSprite2D = $Content/Portrait/VisualRoot/MagicAmbient
@onready var magic_burst: AnimatedSprite2D = $Content/Portrait/VisualRoot/MagicBurst

@export_range(0.0, 2.0, 0.05) var action_recovery_seconds: float = 0.15

var enemy_index: int = -1
var bound_enemy: EnemyData
var _magic_path: String = ""
var _last_hp: int = -1


## Connects body interaction and keeps its visual transform aligned on layout changes.
func _ready() -> void:
	hit_button.pressed.connect(_on_pressed)
	hit_button.add_theme_stylebox_override("hover", _style(Color(1.0, 0.82, 0.74, 0.22), 8, 2))
	hit_button.add_theme_stylebox_override("pressed", _style(Color(1.0, 0.82, 0.74, 0.35), 8, 2))
	portrait.resized.connect(_fit_hit_button)
	visual_root.resized.connect(_fit_hit_button)
	motion.hit_button.mouse_filter = Control.MOUSE_FILTER_IGNORE
	motion.hit_button.disabled = true
	magic_burst.animation_finished.connect(magic_burst.hide)
	hp_bar.add_theme_stylebox_override("background", _style(Color(0.40, 0.34, 0.27), 12, 2))
	hp_bar.add_theme_stylebox_override("fill", _style(HP_RED, 12, 1))
	_apply_target_highlight_style()


## Updates the retained enemy without interrupting its presentation.
func setup(enemy: EnemyData, index: int, selected: bool, target_highlighted: bool) -> void:
	bound_enemy = enemy
	enemy_index = index
	hit_button.disabled = not enemy.is_alive()
	modulate = Color(1, 1, 1, 1.0 if enemy.is_alive() else 0.30)

	var normal_color: Color = Color(0, 0, 0, 0)
	var normal_border: int = 0
	if target_highlighted:
		normal_color = Color(1.0, 0.75, 0.42, 0.34)
		normal_border = 3
	elif selected:
		normal_color = Color(1.0, 0.82, 0.74, 0.23)
		normal_border = 2
	hit_button.add_theme_stylebox_override("normal", _style(normal_color, 8, normal_border))

	hp_bar.max_value = enemy.max_hp
	hp_bar.value = enemy.current_hp
	hp_label.text = "%d / %d" % [enemy.current_hp, enemy.max_hp]
	portrait.texture = load(enemy.portrait_path) as Texture2D
	motion.visible = not enemy.battle_animation_path.is_empty()
	portrait.visible = not motion.visible
	if motion.visible:
		motion.setup(enemy.battle_animation_path, enemy.portrait_path, enemy.is_alive())
		if _last_hp >= 0 and enemy.current_hp < _last_hp and enemy.is_alive():
			motion.play_action(&"hurt")
	_last_hp = enemy.current_hp
	_setup_magic(enemy.magic_animation_path)
	_fit_hit_button()
	shield_visual.setup(enemy.current_shield, enemy.get_damage_reduction())
	_refresh_effects(enemy)
	target_highlight.visible = target_highlighted


## Fits body interaction beneath the same scale and mirror transform as the animation layers.
func _fit_hit_button() -> void:
	_apply_visual_transform()
	var texture: Texture2D = portrait.texture
	if motion.visible and motion.sprite.sprite_frames != null:
		texture = motion.sprite.sprite_frames.get_frame_texture(&"idle", 0)
	if texture == null:
		hit_button.setup_texture(null, Rect2())
		return
	var texture_size: Vector2 = texture.get_size()
	var fit_scale: float = minf(portrait.size.x / maxf(1.0, texture_size.x), portrait.size.y / maxf(1.0, texture_size.y))
	var draw_size: Vector2 = texture_size * fit_scale
	hit_button.setup_texture(texture, Rect2(portrait.position + (portrait.size - draw_size) * 0.5, draw_size))
	for sprite: AnimatedSprite2D in [magic_ambient, magic_burst]:
		sprite.position = portrait.size * 0.5
		sprite.scale = Vector2.ONE * fit_scale


## Scales and mirrors body, magic, and alpha-mask interaction around their shared center.
func _apply_visual_transform() -> void:
	var display_scale: float = bound_enemy.battle_visual_scale if bound_enemy != null else 1.0
	var flipped: bool = bound_enemy != null and bound_enemy.battle_flip_h
	visual_root.pivot_offset = visual_root.size * 0.5
	visual_root.scale = Vector2(-display_scale if flipped else display_scale, display_scale)


## Loads the independent aura once per identity without restarting its ambient loop.
func _setup_magic(path: String) -> void:
	if path == _magic_path:
		return
	_magic_path = path
	var frames: SpriteFrames = load(path) as SpriteFrames if not path.is_empty() else null
	magic_ambient.sprite_frames = frames
	magic_burst.sprite_frames = frames
	magic_burst.hide()
	magic_ambient.visible = frames != null
	if frames != null:
		magic_ambient.play(&"idle")


## Rejects HP bars, status icons, and transparent padding when a card is targeted.
func contains_global_point(mouse_global_position: Vector2) -> bool:
	return hit_button.contains_global_point(mouse_global_position)


## Plays animated enemies and magic separately, retaining the static enemy fallback.
func play_action(is_attack: bool) -> void:
	var frames: SpriteFrames = attack_sprite.sprite_frames
	if is_attack and motion.visible:
		if magic_burst.sprite_frames != null:
			magic_burst.stop()
			magic_burst.show()
			magic_burst.play(&"attack")
		var duration: float = motion.play_action(&"attack")
		if duration > 0.0:
			await get_tree().create_timer(duration).timeout
	elif is_attack and frames != null and frames.has_animation(&"attack"):
		portrait.hide()
		attack_sprite.show()
		attack_sprite.stop()
		attack_sprite.play(&"attack")
		if frames.get_animation_loop(&"attack"):
			await attack_sprite.animation_looped
		else:
			await attack_sprite.animation_finished
		attack_sprite.stop()
		attack_sprite.hide()
		portrait.show()
	elif is_attack:
		attack_animation.play(&"attack")
		await attack_animation.animation_finished
	else:
		var pulse: Tween = create_tween()
		pulse.tween_property(visual_root, "modulate", Color(1.15, 1.08, 0.75), 0.18)
		pulse.tween_property(visual_root, "modulate", Color.WHITE, 0.18)
		await pulse.finished
	if action_recovery_seconds > 0.0:
		await get_tree().create_timer(action_recovery_seconds).timeout


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
