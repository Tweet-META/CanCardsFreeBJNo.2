extends Node
## Manages the three persistent save slots and the active save.

signal active_slot_changed(slot_index: int)
signal slot_list_changed()

const SAVE_VERSION: int = 1
const SLOT_COUNT: int = 3
const SAVE_DIR: String = "user://saves"
const DEFAULT_LEVEL_ID: String = "level1"

var active_slot_index: int = 0
var active_save: SaveSlotData


## Ensures the save directory exists before any slot operation.
func _ready() -> void:
	_ensure_save_dir()


## Returns true when a slot index is one of the three supported slots.
func is_valid_slot(slot_index: int) -> bool:
	return slot_index >= 1 and slot_index <= SLOT_COUNT


## Returns whether a slot file exists on disk.
func slot_exists(slot_index: int) -> bool:
	if not is_valid_slot(slot_index):
		return false
	return FileAccess.file_exists(_slot_path(slot_index))


## Returns a lightweight summary for main-menu slot display.
func get_slot_summary(slot_index: int) -> Dictionary:
	var summary: Dictionary = {
		"exists": false,
		"slot": slot_index,
		"current_level": DEFAULT_LEVEL_ID,
		"updated_at": "",
		"unlocked_character_count": 0
	}
	var save_data: SaveSlotData = load_slot_data(slot_index)
	if save_data == null:
		return summary
	summary["exists"] = true
	summary["current_level"] = save_data.current_level
	summary["updated_at"] = save_data.updated_at
	summary["unlocked_character_count"] = _count_unlocked_characters(save_data)
	return summary


## Creates a new slot, overwriting any existing file in that slot.
func create_new_slot(slot_index: int) -> bool:
	if not is_valid_slot(slot_index):
		return false
	var now: String = Time.get_datetime_string_from_system(false, true)
	var save_data: SaveSlotData = SaveSlotData.new()
	save_data.version = SAVE_VERSION
	save_data.slot = slot_index
	save_data.created_at = now
	save_data.updated_at = now
	save_data.current_level = DEFAULT_LEVEL_ID
	save_data.old_toefl = 0.0
	save_data.character_levels = _default_character_levels()
	active_slot_index = slot_index
	active_save = save_data
	var saved: bool = save_current_slot()
	if saved:
		active_slot_changed.emit(active_slot_index)
		slot_list_changed.emit()
	return saved


## Loads a slot and makes it the active save.
func load_slot(slot_index: int) -> bool:
	var save_data: SaveSlotData = load_slot_data(slot_index)
	if save_data == null:
		return false
	active_slot_index = slot_index
	active_save = save_data
	active_slot_changed.emit(active_slot_index)
	return true


## Loads slot data without changing the active save.
func load_slot_data(slot_index: int) -> SaveSlotData:
	if not slot_exists(slot_index):
		return null
	var file: FileAccess = FileAccess.open(_slot_path(slot_index), FileAccess.READ)
	if file == null:
		push_error("SaveManager: could not open save slot %d." % slot_index)
		return null
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if not parsed is Dictionary:
		push_error("SaveManager: save slot %d is not a JSON object." % slot_index)
		return null
	return SaveSlotData.from_dictionary(parsed as Dictionary, slot_index)


## Saves the active slot to disk.
func save_current_slot() -> bool:
	if active_save == null or not is_valid_slot(active_save.slot):
		return false
	active_save.version = SAVE_VERSION
	active_save.updated_at = Time.get_datetime_string_from_system(false, true)
	_ensure_save_dir()
	var file: FileAccess = FileAccess.open(_slot_path(active_save.slot), FileAccess.WRITE)
	if file == null:
		push_error("SaveManager: could not write save slot %d." % active_save.slot)
		return false
	file.store_string(JSON.stringify(active_save.to_dictionary(), "\t"))
	slot_list_changed.emit()
	return true


## Deletes a slot and clears the active save if it was using that slot.
func delete_slot(slot_index: int) -> bool:
	if not is_valid_slot(slot_index):
		return false
	if slot_exists(slot_index):
		var error: Error = DirAccess.remove_absolute(ProjectSettings.globalize_path(_slot_path(slot_index)))
		if error != OK:
			push_error("SaveManager: could not delete save slot %d." % slot_index)
			return false
	if active_slot_index == slot_index:
		active_slot_index = 0
		active_save = null
		active_slot_changed.emit(active_slot_index)
	slot_list_changed.emit()
	return true


## Returns the active progression level, falling back to the first level.
func get_current_level_id() -> String:
	if active_save == null:
		return DEFAULT_LEVEL_ID
	return active_save.current_level


## Sets the active progression level and saves it.
func set_current_level_id(level_id: String) -> void:
	if active_save == null or level_id.is_empty():
		return
	active_save.current_level = level_id
	save_current_slot()


## Advances the active save to the next mainline level after a clear.
func advance_after_level_clear(cleared_level_id: String) -> void:
	if active_save == null:
		return
	var next_level_id: String = LevelDatabase.get_next_level_id(cleared_level_id)
	if LevelDatabase.get_level_order(next_level_id) > LevelDatabase.get_level_order(active_save.current_level):
		active_save.current_level = next_level_id
		save_current_slot()


## Returns whether a level is reachable in the active mainline progress.
func is_level_unlocked(level_id: String) -> bool:
	if active_save == null:
		return LevelDatabase.is_level_default_unlocked(level_id)
	return LevelDatabase.get_level_order(level_id) <= LevelDatabase.get_level_order(active_save.current_level)


## Returns a character level; level 0 means locked.
func get_character_level(character_id: String) -> int:
	if active_save == null:
		return 1
	return int(active_save.character_levels.get(character_id, 0))


## Returns whether a character is unlocked in the active save.
func is_character_unlocked(character_id: String) -> bool:
	return get_character_level(character_id) > 0


## Sets a character level and saves the active slot.
func set_character_level(character_id: String, level: int) -> void:
	if active_save == null or character_id.is_empty():
		return
	active_save.character_levels[character_id] = maxi(level, 0)
	save_current_slot()


## Counts unlocked characters in one save slot.
func _count_unlocked_characters(save_data: SaveSlotData) -> int:
	var count: int = 0
	for value: Variant in save_data.character_levels.values():
		if int(value) > 0:
			count += 1
	return count


## Builds default character progress for a fresh save.
func _default_character_levels() -> Dictionary:
	var levels: Dictionary = {}
	for character_id: String in CharacterDatabase.get_default_player_ids():
		levels[character_id] = 1
	return levels


## Creates the save directory when it does not exist yet.
func _ensure_save_dir() -> void:
	if not DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(SAVE_DIR)):
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(SAVE_DIR))


## Returns the JSON file path for a slot.
func _slot_path(slot_index: int) -> String:
	return "%s/slot_%d.json" % [SAVE_DIR, slot_index]
