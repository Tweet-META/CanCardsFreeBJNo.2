extends Control
## Presents the tutorial speaker and the current non-modal map instruction.
class_name TutorialGuide

@onready var portrait: TextureRect = $Row/Portrait
@onready var speaker_label: Label = $Row/Speech/Content/Speaker
@onready var message_label: Label = $Row/Speech/Content/Message
var speaker: CharacterData
var message_key: String = ""


## Keeps localization in sync without blocking map or preparation inputs.
func _ready() -> void:
	LanguageManager.language_changed.connect(_on_language_changed)
	hide()


## Shows one data-driven instruction from the configured mascot.
func show_instruction(character: CharacterData, key: String) -> void:
	speaker = character
	message_key = key
	if speaker == null or key.is_empty():
		hide()
		return
	portrait.texture = load(speaker.portrait_path) as Texture2D
	_refresh_text()
	show()


## Updates the visible speaker and message after a language switch.
func _on_language_changed(_locale: String) -> void:
	_refresh_text()


## Uses localization keys for both the speaker and her instruction.
func _refresh_text() -> void:
	if speaker == null:
		return
	speaker_label.text = tr(speaker.display_name)
	message_label.text = tr(message_key)
