extends Button
## Displays and opens the optional learning-goal selection.
class_name LearningGoalButton

@onready var portrait: TextureRect = $Content/Portrait
@onready var character_label: Label = $Content/Text/CharacterLabel
@onready var attribute_label: Label = $Content/Text/AttributeLabel
@onready var summary_label: Label = $Content/Text/SummaryLabel


## Updates the collapsed selector from the current optional choice.
func setup(character: CharacterData, goal: LearningGoalData) -> void:
	if character == null or goal == null:
		portrait.texture = null
		portrait.visible = false
		character_label.text = tr("LEARNING_GOAL_TITLE")
		attribute_label.text = tr("LEARNING_GOAL_NONE")
		summary_label.text = tr("LEARNING_GOAL_OPTIONAL")
		return

	portrait.visible = true
	portrait.texture = _load_portrait(character.portrait_path)
	character_label.text = tr(character.display_name)
	attribute_label.text = tr(goal.display_name)
	summary_label.text = tr(goal.summary)


## Loads a character portrait without assuming every future asset is present.
func _load_portrait(path: String) -> Texture2D:
	if path.is_empty() or not ResourceLoader.exists(path):
		return null
	return load(path) as Texture2D
