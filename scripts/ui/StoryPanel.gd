extends Control
## Plays an optional level-clear sequence, then presents localized fallback dialogue.
class_name StoryPanel

signal completed(event_id: String)

@onready var story_sprite: AnimatedSprite2D = $StorySprite
@onready var loading_label: Label = $LoadingLabel
@onready var dialogue: PanelContainer = $Dialogue
@onready var portrait: TextureRect = $Dialogue/Content/Portrait
@onready var speaker: Label = $Dialogue/Content/Text/Speaker
@onready var message: Label = $Dialogue/Content/Text/Message
@onready var next_button: Button = $Dialogue/Content/Text/Next

var event: StoryEventData
var _line: int = 0


## Keeps the overlay editor-owned and connects one-shot story and dialogue completion.
func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	next_button.pressed.connect(_next_line)
	story_sprite.animation_finished.connect(_show_dialogue)
	resized.connect(_fit_story)
	LanguageManager.language_changed.connect(_refresh_language)
	hide()


## Skips the empty sequence slot today while keeping its dialogue and rewards visible.
func open_event(story_event: StoryEventData) -> void:
	event = story_event
	_line = 0
	dialogue.hide()
	story_sprite.hide()
	loading_label.hide()
	show()
	if event.sprite_frames_path.is_empty():
		_show_dialogue()
		return
	loading_label.text = tr("LOADING_STATUS")
	loading_label.show()
	var error: Error = ResourceLoader.load_threaded_request(event.sprite_frames_path, "SpriteFrames")
	if error == OK:
		var status: ResourceLoader.ThreadLoadStatus = ResourceLoader.load_threaded_get_status(event.sprite_frames_path)
		while status == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
			await get_tree().process_frame
			status = ResourceLoader.load_threaded_get_status(event.sprite_frames_path)
		if status == ResourceLoader.THREAD_LOAD_LOADED:
			var source: SpriteFrames = ResourceLoader.load_threaded_get(event.sprite_frames_path) as SpriteFrames
			if source != null and source.has_animation(event.animation) and source.get_frame_count(event.animation) > 0:
				var frames: SpriteFrames = source.duplicate() as SpriteFrames
				frames.set_animation_loop(event.animation, false)
				story_sprite.sprite_frames = frames
				story_sprite.play(event.animation)
				story_sprite.show()
				loading_label.hide()
				_fit_story()
				return
	push_error("StoryPanel: configured sequence cannot be played: %s" % event.sprite_frames_path)
	_show_dialogue()


## Fits future story frames without changing their aspect ratio.
func _fit_story() -> void:
	story_sprite.position = size * 0.5
	var frames: SpriteFrames = story_sprite.sprite_frames
	if frames == null or not frames.has_animation(story_sprite.animation) or frames.get_frame_count(story_sprite.animation) == 0:
		return
	var texture: Texture2D = frames.get_frame_texture(story_sprite.animation, 0)
	if texture != null:
		var frame_size: Vector2 = texture.get_size()
		story_sprite.scale = Vector2.ONE * minf(size.x / maxf(1.0, frame_size.x), size.y / maxf(1.0, frame_size.y))


## Shows a clean speaker portrait independently from any battle magic layer.
func _show_dialogue() -> void:
	loading_label.hide()
	story_sprite.hide()
	portrait.texture = load(event.portrait_path) as Texture2D if not event.portrait_path.is_empty() else null
	dialogue.show()
	_refresh_language()
	next_button.grab_focus()


## Advances dialogue and emits completion only after its final line is acknowledged.
func _next_line() -> void:
	_line += 1
	if _line >= event.dialogue_keys.size():
		hide()
		completed.emit(event.id)
		return
	_refresh_language()


## Refreshes the localized line and expands authored line breaks without advancing the story.
func _refresh_language(_locale: String = "") -> void:
	if event == null:
		return
	speaker.text = tr(event.speaker_name)
	message.text = tr(event.dialogue_keys[_line]).replace("\\n", "\n") if _line < event.dialogue_keys.size() else ""
	next_button.text = tr("STORY_CONTINUE")
