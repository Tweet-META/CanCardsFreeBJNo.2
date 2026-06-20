extends RefCounted
class_name CharacterDatabase

const DATA_PATH: String = "res://data/characters.json"

static var _loaded: bool = false
static var _root_data: Dictionary = {}
static var _definitions: Dictionary = {}


static func create_character(character_id: String) -> CharacterData:
	_ensure_loaded()
	var raw_value: Variant = _definitions.get(character_id)
	if not raw_value is Dictionary:
		push_error("CharacterDatabase: unknown character id '%s'." % character_id)
		return null

	var raw: Dictionary = raw_value as Dictionary
	var character: CharacterData = CharacterData.new()
	character.id = str(raw.get("id", ""))
	character.display_name = str(raw.get("display_name", ""))
	character.attribute = LearningAttribute.from_id(str(raw.get("attribute", "")))
	character.max_hp = int(raw.get("max_hp", 100))
	character.defense = int(raw.get("defense", 0))
	character.portrait_path = str(raw.get("portrait_path", ""))
	character.cards = CardDatabase.create_cards(_to_string_array(raw.get("cards", [])))
	return character


static func create_default_team() -> Array[CharacterData]:
	_ensure_loaded()
	var team: Array[CharacterData] = []
	for character_id: String in _to_string_array(_root_data.get("player_team", [])):
		var character: CharacterData = create_character(character_id)
		if character != null:
			team.append(character)
	return team


static func reload() -> void:
	_loaded = false
	_root_data.clear()
	_definitions.clear()
	_ensure_loaded()


static func _ensure_loaded() -> void:
	if _loaded:
		return
	_loaded = true

	var file: FileAccess = FileAccess.open(DATA_PATH, FileAccess.READ)
	if file == null:
		push_error("CharacterDatabase: could not open %s." % DATA_PATH)
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if not parsed is Dictionary:
		push_error("CharacterDatabase: %s must contain a JSON object." % DATA_PATH)
		return

	_root_data = parsed as Dictionary
	var characters_value: Variant = _root_data.get("characters")
	if not characters_value is Array:
		push_error("CharacterDatabase: characters must be an array.")
		return
	for raw_value: Variant in characters_value as Array:
		if not raw_value is Dictionary:
			continue
		var raw: Dictionary = raw_value as Dictionary
		var character_id: String = str(raw.get("id", ""))
		if character_id.is_empty():
			push_error("CharacterDatabase: character definition is missing an id.")
			continue
		if _definitions.has(character_id):
			push_error("CharacterDatabase: duplicate character id '%s'." % character_id)
			continue
		_definitions[character_id] = raw


static func _to_string_array(value: Variant) -> Array[String]:
	var result: Array[String] = []
	if not value is Array:
		return result
	for item: Variant in value as Array:
		result.append(str(item))
	return result
