extends RefCounted
## Loads tutorial content and the reserved opening sequence from editable JSON.
class_name TutorialDatabase

const DATA_PATH: String = "res://data/tutorials.json"
static var _loaded: bool = false
static var _definitions: Dictionary = {}
static var _opening_sequence: Dictionary = {}


## Resolves the tutorial referenced by a level definition.
static func create_for_level(level: LevelData) -> TutorialData:
	_ensure_loaded()
	if level == null or level.tutorial_id.is_empty():
		return null
	var raw_value: Variant = _definitions.get(level.tutorial_id)
	if not raw_value is Dictionary:
		push_error("TutorialDatabase: unknown tutorial '%s'." % level.tutorial_id)
		return null
	var raw: Dictionary = raw_value as Dictionary
	var tutorial: TutorialData = TutorialData.new()
	tutorial.id = str(raw.get("id", ""))
	tutorial.level_id = str(raw.get("level_id", ""))
	tutorial.speaker_id = str(raw.get("speaker_id", ""))
	if tutorial.level_id != level.id:
		push_error("TutorialDatabase: tutorial and owning level do not match.")
		return null
	var map_value: Variant = raw.get("map_steps", {})
	var battle_value: Variant = raw.get("battle_steps", {})
	if map_value is Dictionary:
		tutorial.map_steps = (map_value as Dictionary).duplicate()
	if battle_value is Dictionary:
		tutorial.battle_steps = (battle_value as Dictionary).duplicate()
	return tutorial


## Returns the optional SpriteFrames resource for the future opening story.
static func get_opening_frames_path() -> String:
	_ensure_loaded()
	return str(_opening_sequence.get("sprite_frames_path", ""))


## Returns the named one-shot animation that leads into the map.
static func get_opening_animation() -> StringName:
	_ensure_loaded()
	return StringName(str(_opening_sequence.get("animation", "intro")))


## Parses the source once and validates tutorial identities.
static func _ensure_loaded() -> void:
	if _loaded:
		return
	_loaded = true
	var file: FileAccess = FileAccess.open(DATA_PATH, FileAccess.READ)
	if file == null:
		push_error("TutorialDatabase: cannot open %s." % DATA_PATH)
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if not parsed is Dictionary:
		push_error("TutorialDatabase: source must contain an object.")
		return
	var root: Dictionary = parsed as Dictionary
	var opening_value: Variant = root.get("opening_sequence", {})
	if opening_value is Dictionary:
		_opening_sequence = opening_value as Dictionary
	var rows_value: Variant = root.get("tutorials", [])
	if not rows_value is Array:
		return
	for raw_value: Variant in rows_value as Array:
		if not raw_value is Dictionary:
			continue
		var raw: Dictionary = raw_value as Dictionary
		var tutorial_id: String = str(raw.get("id", ""))
		if tutorial_id.is_empty() or _definitions.has(tutorial_id):
			push_error("TutorialDatabase: missing or duplicate tutorial id.")
			continue
		_definitions[tutorial_id] = raw
