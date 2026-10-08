extends RefCounted
## Loads the battle-wide learning goals available for character attributes.
class_name LearningGoalDatabase

const DATA_PATH: String = "res://data/learning_goals.json"

static var _loaded: bool = false
static var _definitions: Dictionary = {}


## Creates a fresh learning goal from its stable ID.
static func create_goal(goal_id: String) -> LearningGoalData:
	_ensure_loaded()
	var raw_value: Variant = _definitions.get(goal_id)
	if not raw_value is Dictionary:
		push_error("LearningGoalDatabase: unknown learning goal id '%s'." % goal_id)
		return null

	var raw: Dictionary = raw_value as Dictionary
	var goal: LearningGoalData = LearningGoalData.new()
	goal.id = str(raw.get("id", ""))
	goal.attribute = LearningAttribute.from_id(str(raw.get("attribute", "")))
	goal.display_name = str(raw.get("display_name", ""))
	goal.description = str(raw.get("description", ""))
	goal.summary = str(raw.get("summary", ""))
	goal.team_stat_multiplier = float(raw.get("team_stat_multiplier", 1.0))
	goal.wrong_answer_bonus_chance = float(raw.get("wrong_answer_bonus_chance", 0.0))
	goal.ap_growth_bonus = float(raw.get("ap_growth_bonus", 0.0))
	return goal


## Creates the goal associated with a character's learning attribute.
static func create_goal_for_character(character: CharacterData) -> LearningGoalData:
	if character == null:
		return null
	return create_goal(LearningAttribute.to_id(character.attribute))


## Clears cached definitions so edited JSON can be loaded again.
static func reload() -> void:
	_loaded = false
	_definitions.clear()
	_ensure_loaded()


## Loads and validates all learning goal definitions once.
static func _ensure_loaded() -> void:
	if _loaded:
		return
	_loaded = true

	var file: FileAccess = FileAccess.open(DATA_PATH, FileAccess.READ)
	if file == null:
		push_error("LearningGoalDatabase: could not open %s." % DATA_PATH)
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if not parsed is Dictionary:
		push_error("LearningGoalDatabase: %s must contain a JSON object." % DATA_PATH)
		return

	var goals_value: Variant = (parsed as Dictionary).get("learning_goals", [])
	if not goals_value is Array:
		push_error("LearningGoalDatabase: learning_goals must be an array.")
		return
	for raw_value: Variant in goals_value as Array:
		if not raw_value is Dictionary:
			continue
		var raw: Dictionary = raw_value as Dictionary
		var goal_id: String = str(raw.get("id", ""))
		if goal_id.is_empty():
			push_error("LearningGoalDatabase: learning goal definition is missing an id.")
			continue
		if _definitions.has(goal_id):
			push_error("LearningGoalDatabase: duplicate learning goal id '%s'." % goal_id)
			continue
		_definitions[goal_id] = raw
