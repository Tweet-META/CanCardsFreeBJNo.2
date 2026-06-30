extends Button
## Represents one selectable player character in the preparation panel.
class_name CharacterSelectButton

signal character_toggled(character_id: String)

var character_id: String = ""


## Applies character display state to the button.
func setup(character: CharacterData, selected: bool, locked: bool) -> void:
	character_id = character.id
	text = tr(character.display_name)
	toggle_mode = true
	button_pressed = selected
	disabled = locked


## Emits the configured character ID when pressed.
func _pressed() -> void:
	character_toggled.emit(character_id)
