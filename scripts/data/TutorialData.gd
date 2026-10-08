extends Resource
## Stores one localized tutorial's map and battle guidance.
class_name TutorialData

@export var id: String = ""
@export var level_id: String = ""
@export var speaker_id: String = ""
@export var map_steps: Dictionary = {}
@export var battle_steps: Dictionary = {}


## Returns a configured localization key, leaving unknown steps absent.
func get_map_message(step: String) -> String:
	return str(map_steps.get(step, ""))


## Returns a battle-log instruction without embedding its text in combat code.
func get_battle_message(step: String) -> String:
	return str(battle_steps.get(step, ""))
