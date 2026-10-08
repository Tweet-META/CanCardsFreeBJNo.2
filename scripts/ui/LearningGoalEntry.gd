extends Button
## Represents one unlocked character as a selectable learning-goal source.
class_name LearningGoalEntry

signal goal_source_selected(character_id: String)

var character_id: String = ""

@onready var portrait: TextureRect = $Content/Portrait
@onready var character_label: Label = $Content/Text/CharacterLabel
@onready var attribute_label: Label = $Content/Text/AttributeLabel
@onready var description_label: Label = $Content/Text/DescriptionLabel


## Applies one unlocked character and its attribute goal to this entry.
func setup(character: CharacterData, goal: LearningGoalData, selected: bool) -> void:
	character_id = character.id
	portrait.texture = _load_portrait(character.portrait_path)
	character_label.text = tr(character.display_name)
	attribute_label.text = tr(goal.display_name)
	description_label.text = tr(goal.description)
	button_pressed = selected


## Emits the selected character ID to the owning drawer.
func _pressed() -> void:
	goal_source_selected.emit(character_id)


## Loads a character portrait while tolerating a missing future asset.
func _load_portrait(path: String) -> Texture2D:
	if path.is_empty() or not ResourceLoader.exists(path):
		return null
	return load(path) as Texture2D
