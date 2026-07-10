extends Control
## Defines the LevelNode script.
class_name LevelNode

signal level_selected(level: LevelData)

@onready var level_button: Button = $LevelButton
@onready var level_label: Label = $LevelLabel

var level_data: LevelData


## Ready.
func _ready() -> void:
	level_button.pressed.connect(_on_pressed)


## Setup.
func setup(level: LevelData) -> void:
	level_data = level
	level_button.disabled = not level.unlocked
	level_button.text = level.marker_text
	level_label.text = tr(level.display_name)
	modulate = Color.WHITE if level.unlocked else Color.TRANSPARENT


## Refresh language.
func refresh_language() -> void:
	if level_data == null:
		return
	level_label.text = tr(level_data.display_name)


## On pressed.
func _on_pressed() -> void:
	if level_data != null and level_data.unlocked:
		level_selected.emit(level_data)
