extends Resource
## Runtime representation of one save slot.
class_name SaveSlotData

@export var version: int = 1
@export var slot: int = 0
@export var created_at: String = ""
@export var updated_at: String = ""
@export var current_level: String = "level1"
@export var old_toefl: float = 0.0
@export var character_levels: Dictionary = {}


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
		"characters": character_levels
	}


## Builds a save slot resource from parsed JSON data.
static func from_dictionary(data: Dictionary, fallback_slot: int) -> SaveSlotData:
	var save_data: SaveSlotData = SaveSlotData.new()
	save_data.version = int(data.get("version", 1))
	save_data.slot = int(data.get("slot", fallback_slot))
	save_data.created_at = str(data.get("created_at", ""))
	save_data.updated_at = str(data.get("updated_at", ""))
	save_data.current_level = str(data.get("current_level", "level1"))
	save_data.old_toefl = float(data.get("old_toefl", 0.0))
	var levels_value: Variant = data.get("characters", {})
	if levels_value is Dictionary:
		save_data.character_levels = (levels_value as Dictionary).duplicate(true)
	return save_data
