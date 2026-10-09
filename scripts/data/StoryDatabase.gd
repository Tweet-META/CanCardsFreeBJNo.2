extends RefCounted
## Loads level-clear story slots independently from combat rules and UI.
class_name StoryDatabase

const DATA_PATH: String = "res://data/story_events.json"
static var _loaded: bool = false
static var _events: Array[StoryEventData] = []


## Returns the first unseen story belonging to a cleared level.
static func get_pending(cleared: Array[String], completed: Array[String]) -> StoryEventData:
	_ensure_loaded()
	for event: StoryEventData in _events:
		if event.level_id in cleared and event.id not in completed:
			return event
	return null


## Finds the data-driven progression rewards for a level clear.
static func for_level(level_id: String) -> StoryEventData:
	_ensure_loaded()
	for event: StoryEventData in _events:
		if event.level_id == level_id:
			return event
	return null


## Checks feature progression from cleared levels rather than entering a numbered level.
static func general_cards_unlocked(cleared: Array[String]) -> bool:
	_ensure_loaded()
	for event: StoryEventData in _events:
		if event.unlock_general_cards and event.level_id in cleared:
			return true
	return false


## Reads localized dialogue and optional future SpriteFrames slots from JSON.
static func _ensure_loaded() -> void:
	if _loaded:
		return
	_loaded = true
	var file: FileAccess = FileAccess.open(DATA_PATH, FileAccess.READ)
	if file == null:
		push_error("StoryDatabase: could not open story data.")
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if not parsed is Dictionary:
		push_error("StoryDatabase: story data must be an object.")
		return
	var root: Dictionary = parsed as Dictionary
	var items: Array = root.get("events", []) as Array
	for value: Variant in items:
		if not value is Dictionary:
			continue
		var raw: Dictionary = value as Dictionary
		var event: StoryEventData = StoryEventData.new()
		event.id = str(raw.get("id", ""))
		event.level_id = str(raw.get("level_id", ""))
		event.sprite_frames_path = str(raw.get("sprite_frames_path", ""))
		event.animation = StringName(str(raw.get("animation", "story")))
		event.speaker_name = str(raw.get("speaker_name", ""))
		event.portrait_path = str(raw.get("portrait_path", ""))
		event.unlock_general_cards = bool(raw.get("unlock_general_cards", false))
		for key: Variant in raw.get("dialogue", []) as Array:
			event.dialogue_keys.append(str(key))
		for character_id: Variant in raw.get("unlock_characters", []) as Array:
			event.unlock_character_ids.append(str(character_id))
		_events.append(event)
