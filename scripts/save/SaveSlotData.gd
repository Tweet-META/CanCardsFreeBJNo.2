extends Resource
## Runtime representation of one save slot.
class_name SaveSlotData

@export var version: int = 3
@export var slot: int = 0
@export var created_at: String = ""
@export var updated_at: String = ""
@export var current_level: String = "level1"
@export var old_toefl: float = 0.0
@export var character_levels: Dictionary = {}
@export var opening_completed: bool = false
@export var tutorial_completed: bool = false
@export var cleared_levels: Array[String] = []
@export var completed_story_events: Array[String] = []
@export var unlocked_general_cards: Array[String] = []


## Returns true when the slot contains usable saved progress.
func is_valid() -> bool:
	return slot >= 1 and slot <= SaveManager.SLOT_COUNT and not current_level.is_empty()


## Converts this runtime resource into a JSON-safe dictionary.
func to_dictionary() -> Dictionary:
	return {
		"version": version,
		"slot": slot,
		"created_at": created_at,
		"updated_at": updated_at,
		"current_level": current_level,
		"old_toefl": old_toefl,
		"characters": character_levels,
		"opening_completed": opening_completed,
		"tutorial_completed": tutorial_completed,
		"cleared_levels": cleared_levels,
		"completed_story_events": completed_story_events,
		"unlocked_general_cards": unlocked_general_cards
	}


## Loads progression and conservatively infers earlier clears for legacy slots.
static func from_dictionary(data: Dictionary, fallback_slot: int) -> SaveSlotData:
	var save_data: SaveSlotData = SaveSlotData.new()
	save_data.version = int(data.get("version", 1))
	save_data.slot = int(data.get("slot", fallback_slot))
	save_data.created_at = str(data.get("created_at", ""))
	save_data.updated_at = str(data.get("updated_at", ""))
	save_data.current_level = str(data.get("current_level", "level1"))
	save_data.opening_completed = bool(data.get("opening_completed", true))
	save_data.tutorial_completed = bool(data.get("tutorial_completed", save_data.current_level != SaveManager.DEFAULT_LEVEL_ID))
	save_data.old_toefl = float(data.get("old_toefl", 0.0))
	var levels_value: Variant = data.get("characters", {})
	if levels_value is Dictionary:
		save_data.character_levels = (levels_value as Dictionary).duplicate(true)
	if data.has("cleared_levels"):
		for value: Variant in data.get("cleared_levels", []) as Array:
			save_data.cleared_levels.append(str(value))
	else:
		var current_order: int = LevelDatabase.get_level_order(save_data.current_level)
		for level_id: String in LevelDatabase.get_mainline_ids():
			if LevelDatabase.get_level_order(level_id) < current_order:
				save_data.cleared_levels.append(level_id)
	for value: Variant in data.get("completed_story_events", []) as Array:
		save_data.completed_story_events.append(str(value))
	if data.has("unlocked_general_cards"):
		for value: Variant in data.get("unlocked_general_cards", []) as Array:
			save_data.unlocked_general_cards.append(str(value))
	else:
		save_data.unlocked_general_cards = CardDatabase.get_initial_general_card_ids()
	return save_data
