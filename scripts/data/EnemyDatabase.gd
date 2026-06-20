extends RefCounted
class_name EnemyDatabase

const DATA_PATH: String = "res://data/enemies.json"

static var _loaded: bool = false
static var _root_data: Dictionary = {}
static var _definitions: Dictionary = {}


static func create_enemy(enemy_id: String) -> EnemyData:
	_ensure_loaded()
	var raw_value: Variant = _definitions.get(enemy_id)
	if not raw_value is Dictionary:
		push_error("EnemyDatabase: unknown enemy id '%s'." % enemy_id)
		return null

	var raw: Dictionary = raw_value as Dictionary
	var enemy: EnemyData = EnemyData.new()
	enemy.id = str(raw.get("id", ""))
	enemy.display_name = str(raw.get("display_name", ""))
	enemy.attribute = LearningAttribute.from_id(str(raw.get("attribute", "")))
	enemy.max_hp = int(raw.get("max_hp", 80))
	enemy.attack = int(raw.get("attack", 12))
	enemy.defense = int(raw.get("defense", 0))
	enemy.toefl_reward = float(raw.get("toefl_reward", 0.0))
	enemy.portrait_path = str(raw.get("portrait_path", ""))
	return enemy


static func create_default_team() -> Array[EnemyData]:
	_ensure_loaded()
	var team: Array[EnemyData] = []
	for enemy_id: String in _to_string_array(_root_data.get("enemy_team", [])):
		var enemy: EnemyData = create_enemy(enemy_id)
		if enemy != null:
			team.append(enemy)
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
		push_error("EnemyDatabase: could not open %s." % DATA_PATH)
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if not parsed is Dictionary:
		push_error("EnemyDatabase: %s must contain a JSON object." % DATA_PATH)
		return

	_root_data = parsed as Dictionary
	var enemies_value: Variant = _root_data.get("enemies")
	if not enemies_value is Array:
		push_error("EnemyDatabase: enemies must be an array.")
		return
	for raw_value: Variant in enemies_value as Array:
		if not raw_value is Dictionary:
			continue
		var raw: Dictionary = raw_value as Dictionary
		var enemy_id: String = str(raw.get("id", ""))
		if enemy_id.is_empty():
			push_error("EnemyDatabase: enemy definition is missing an id.")
			continue
		if _definitions.has(enemy_id):
			push_error("EnemyDatabase: duplicate enemy id '%s'." % enemy_id)
			continue
		_definitions[enemy_id] = raw


static func _to_string_array(value: Variant) -> Array[String]:
	var result: Array[String] = []
	if not value is Array:
		return result
	for item: Variant in value as Array:
		result.append(str(item))
	return result
