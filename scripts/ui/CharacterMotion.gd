extends Control
## Plays editor-owned SpriteFrames while retaining a static fallback for future characters.
class_name CharacterMotion

@export var playback_speed: float = 1.0
@export_range(1.0, 60.0, 1.0) var selection_jump_height: float = 16.0
@export_range(100.0, 4000.0, 50.0) var selection_jump_gravity: float = 1000.0

@onready var visual_root: Control = $VisualRoot
@onready var sprite: AnimatedSprite2D = $VisualRoot/AnimatedSprite2D
@onready var static_portrait: TextureRect = $VisualRoot/StaticPortrait
@onready var hit_button: PortraitHitButton = $VisualRoot/HitButton

var resource_path: String = ""
var living: bool = true
var _jump_time: float = 0.0
var _jump_velocity: float = 0.0
var _jump_gravity: float = 0.0
var _jump_duration: float = 0.0
var _visual_baseline: Vector2 = Vector2.ZERO


## Fits the animation to the existing portrait area and restores idle after one-shot actions.
func _ready() -> void:
	set_process(false)
	_visual_baseline = visual_root.position
	resized.connect(_fit_sprite)
	sprite.animation_finished.connect(_on_animation_finished)
	_fit_sprite()


## Changes resources only when the character changes, so UI refreshes never restart idle.
func setup(animation_path: String, portrait_path: String, is_living: bool) -> void:
	living = is_living
	if not living:
		_reset_selection_jump()
	sprite.speed_scale = maxf(0.01, playback_speed)
	if resource_path != animation_path or (sprite.sprite_frames == null and static_portrait.texture == null):
		resource_path = animation_path
		var frames: SpriteFrames = null
		if not animation_path.is_empty() and ResourceLoader.exists(animation_path):
			frames = load(animation_path) as SpriteFrames
		sprite.sprite_frames = frames
		sprite.visible = frames != null
		static_portrait.visible = frames == null
		static_portrait.texture = load(portrait_path) as Texture2D if frames == null and not portrait_path.is_empty() else null
		if frames != null and frames.has_animation(&"idle"):
			sprite.play(&"idle")
	if not living and sprite.animation == &"idle":
		sprite.pause()
	_fit_sprite()


## Starts a single action and returns its duration for parallel group-hit playback.
func play_action(animation_name: StringName) -> float:
	_reset_selection_jump()
	var frames: SpriteFrames = sprite.sprite_frames
	if frames == null or not frames.has_animation(animation_name):
		return 0.0
	sprite.speed_scale = maxf(0.01, playback_speed)
	sprite.stop()
	sprite.play(animation_name)
	var frame_duration: float = 0.0
	for frame_index in frames.get_frame_count(animation_name):
		frame_duration += frames.get_frame_duration(animation_name, frame_index)
	return frame_duration / maxf(0.01, frames.get_animation_speed(animation_name) * sprite.speed_scale)


## Moves only the portrait layer along a ballistic arc; repeated refreshes do not restart it.
func play_selection_jump() -> void:
	if not living or is_processing():
		return
	_jump_time = 0.0
	_jump_gravity = maxf(1.0, selection_jump_gravity)
	_jump_velocity = -sqrt(2.0 * _jump_gravity * maxf(0.0, selection_jump_height))
	_jump_duration = -2.0 * _jump_velocity / _jump_gravity
	set_process(true)


## Uses constant gravity so ascent slows naturally and descent accelerates to the fixed baseline.
func _process(delta: float) -> void:
	_jump_time += delta
	if _jump_time >= _jump_duration:
		_reset_selection_jump()
		return
	var jump_y: float = _jump_velocity * _jump_time + 0.5 * _jump_gravity * _jump_time * _jump_time
	visual_root.position = _visual_baseline + Vector2(0.0, jump_y)


## Lands exactly at the editor-authored portrait baseline before combat playback or defeat.
func _reset_selection_jump() -> void:
	set_process(false)
	_jump_time = 0.0
	visual_root.position = _visual_baseline


## Fits the visual canvas and derives interaction bounds from the idle body, excluding attack effects.
func _fit_sprite() -> void:
	sprite.position = size * 0.5
	var frames: SpriteFrames = sprite.sprite_frames
	var texture: Texture2D = static_portrait.texture
	if frames != null and frames.has_animation(&"idle") and frames.get_frame_count(&"idle") > 0:
		texture = frames.get_frame_texture(&"idle", 0)
	if texture == null:
		hit_button.setup_texture(null, Rect2())
		return
	var texture_size: Vector2 = texture.get_size()
	var fit_scale: float = minf(size.x / maxf(1.0, texture_size.x), size.y / maxf(1.0, texture_size.y))
	sprite.scale = Vector2.ONE * fit_scale
	var draw_size: Vector2 = texture_size * fit_scale
	hit_button.setup_texture(texture, Rect2((size - draw_size) * 0.5, draw_size))


## Returns living characters to idle; defeated characters retain their final hurt pose.
func _on_animation_finished() -> void:
	if living and sprite.sprite_frames != null and sprite.sprite_frames.has_animation(&"idle"):
		sprite.play(&"idle")
