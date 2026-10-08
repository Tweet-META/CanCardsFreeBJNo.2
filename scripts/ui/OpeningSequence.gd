extends Control
## Plays the future opening SpriteFrames once, then hands new saves to the map tutorial.

@onready var sprite: AnimatedSprite2D = $StorySprite
var _finished: bool = false


## Skips an empty story slot today and plays it automatically when its resource is configured.
func _ready() -> void:
	resized.connect(_fit_story)
	var path: String = TutorialDatabase.get_opening_frames_path()
	if path.is_empty():
		_finish_opening.call_deferred()
		return
	var source: SpriteFrames = load(path) as SpriteFrames
	var animation_name: StringName = TutorialDatabase.get_opening_animation()
	if source == null or not source.has_animation(animation_name) or source.get_frame_count(animation_name) == 0:
		push_error("OpeningSequence: configured story must contain a playable animation.")
		_finish_opening.call_deferred()
		return
	var frames: SpriteFrames = source.duplicate() as SpriteFrames
	frames.set_animation_loop(animation_name, false)
	sprite.sprite_frames = frames
	sprite.animation_finished.connect(_finish_opening)
	sprite.play(animation_name)
	_fit_story()


## Preserves the story canvas aspect ratio across viewport sizes.
func _fit_story() -> void:
	sprite.position = size * 0.5
	var frames: SpriteFrames = sprite.sprite_frames
	if frames == null:
		return
	var texture: Texture2D = frames.get_frame_texture(sprite.animation, 0)
	if texture == null:
		return
	var frame_size: Vector2 = texture.get_size()
	sprite.scale = Vector2.ONE * minf(size.x / maxf(1.0, frame_size.x), size.y / maxf(1.0, frame_size.y))


## Persists the one-time opening handoff before entering the map.
func _finish_opening() -> void:
	if _finished:
		return
	_finished = true
	SaveManager.complete_opening_sequence()
	get_tree().change_scene_to_file("res://scenes/MapScene.tscn")
