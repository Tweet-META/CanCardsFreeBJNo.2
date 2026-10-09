extends Node
## Manages the three persistent save slots and the active save.

signal active_slot_changed(slot_index: int)
signal slot_list_changed()

const SAVE_VERSION: int = 3
const SLOT_COUNT: int = 3
const SAVE_DIR: String = "user://saves"
const DEFAULT_LEVEL_ID: String = "level1"
const NEW_TO_OLD_MULTIPLIER: float = 5.0

var active_slot_index: int = 0
var _session_cleared_levels: Array[String] = []
var _session_completed_events: Array[String] = []
var _session_card_unlocks: Array[String] = []
var _session_old_toefl: float = 0.0
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


## Creates a fresh slot with explicit starter card ownership and initial character progress.
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
	save_data.unlocked_general_cards = CardDatabase.get_initial_general_card_ids()
	active_slot_index = slot_index
	active_save = save_data
	var saved: bool = save_current_slot()
	if saved:
		active_slot_changed.emit(active_slot_index)
		slot_list_changed.emit()
	return saved


## Loads a slot and restores character rewards for conservatively migrated clears.
func load_slot(slot_index: int) -> bool:
	var save_data: SaveSlotData = load_slot_data(slot_index)
	if save_data == null:
		return false
	active_slot_index = slot_index
	active_save = save_data
	_restore_clear_rewards()
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


## Records clears and applies data-driven character and feature progression rewards.
func advance_after_level_clear(cleared_level_id: String) -> void:
	if active_save == null:
		if cleared_level_id not in _session_cleared_levels:
			_session_cleared_levels.append(cleared_level_id)
		return
	var next_level_id: String = LevelDatabase.get_next_level_id(cleared_level_id)
	var cleared_level: LevelData = LevelDatabase.create_level(cleared_level_id)
	var changed: bool = false
	if cleared_level_id not in active_save.cleared_levels:
		active_save.cleared_levels.append(cleared_level_id)
		changed = true
	_restore_clear_rewards()
	if cleared_level != null and not cleared_level.tutorial_id.is_empty() and not active_save.tutorial_completed:
		active_save.tutorial_completed = true
		changed = true
	if LevelDatabase.get_level_order(next_level_id) > LevelDatabase.get_level_order(active_save.current_level):
		active_save.current_level = next_level_id
		changed = true
	if changed:
		save_current_slot()


## Applies character unlocks without resetting any existing character level.
func _restore_clear_rewards() -> void:
	if active_save == null:
		return
	for level_id: String in active_save.cleared_levels:
		var event: StoryEventData = StoryDatabase.for_level(level_id)
		if event == null:
			continue
		for character_id: String in event.unlock_character_ids:
			active_save.character_levels[character_id] = maxi(1, int(active_save.character_levels.get(character_id, 0)))


## Returns the cleared levels for the active slot or direct editor session.
func get_cleared_levels() -> Array[String]:
	return active_save.cleared_levels.duplicate() if active_save != null else _session_cleared_levels.duplicate()


## Requires the configured unlocking level to be defeated before card features are enabled.
func are_general_cards_unlocked() -> bool:
	return StoryDatabase.general_cards_unlocked(get_cleared_levels())


## Separates permanent card ownership from the global shop feature unlock.
func is_general_card_unlocked(card_id: String) -> bool:
	if active_save != null:
		return card_id in active_save.unlocked_general_cards
	return card_id in _session_card_unlocks or card_id in CardDatabase.get_initial_general_card_ids()


## Returns the next unseen level-clear sequence for the map handoff.
func get_pending_story() -> StoryEventData:
	var completed: Array[String] = active_save.completed_story_events if active_save != null else _session_completed_events
	return StoryDatabase.get_pending(get_cleared_levels(), completed)


## Persists dialogue completion only after the sequence and fallback text have finished.
func complete_story(event_id: String) -> void:
	if active_save != null:
		if event_id not in active_save.completed_story_events:
			active_save.completed_story_events.append(event_id)
			save_current_slot()
	elif event_id not in _session_completed_events:
		_session_completed_events.append(event_id)


## Returns the persistent Old TOEFL balance used only by David's unlock stall.
func get_old_toefl() -> float:
	return active_save.old_toefl if active_save != null else _session_old_toefl


## Converts a victory's remaining New TOEFL into an integer Old TOEFL deposit.
func settle_battle_currency(balance: float) -> int:
	var gained: int = floori(maxf(0.0, balance) * NEW_TO_OLD_MULTIPLIER + 0.000001)
	if active_save != null:
		active_save.old_toefl += float(gained)
		save_current_slot()
	else:
		_session_old_toefl += float(gained)
	return gained


## Charges Old TOEFL once for a valid locked general card and persists the unlock.
func purchase_general_unlock(card_id: String) -> bool:
	if active_save == null or not are_general_cards_unlocked() or is_general_card_unlocked(card_id):
		return false
	var valid_offer: bool = false
	for card: CardData in CardDatabase.create_vendor_cards():
		if card.id == card_id:
			valid_offer = true
			break
	if not valid_offer:
		return false
	var card: CardData = CardDatabase.create_card(card_id)
	if card == null or active_save.old_toefl + 0.001 < card.unlock_price:
		return false
	active_save.old_toefl = maxf(0.0, active_save.old_toefl - card.unlock_price)
	active_save.unlocked_general_cards.append(card_id)
	save_current_slot()
	return true


## Keeps the opening entry active until its future one-shot sequence has finished.
func needs_opening_sequence() -> bool:
	return active_save != null and not active_save.opening_completed


## Persists opening completion; an empty configured sequence is treated as skipped.
func complete_opening_sequence() -> void:
	if active_save != null and not active_save.opening_completed:
		active_save.opening_completed = true
		save_current_slot()


## Allows first-level guidance for fresh saves and unfinished tutorials.
func needs_first_tutorial() -> bool:
	return active_save == null or not active_save.tutorial_completed


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
		if character_id == "budding":
			levels[character_id] = 1
		else:
			levels[character_id] = 0
	return levels


## Creates the save directory when it does not exist yet.
func _ensure_save_dir() -> void:
	if not DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(SAVE_DIR)):
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(SAVE_DIR))


## Returns the JSON file path for a slot.
func _slot_path(slot_index: int) -> String:
	return "%s/slot_%d.json" % [SAVE_DIR, slot_index]
