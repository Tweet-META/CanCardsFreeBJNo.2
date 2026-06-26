extends RefCounted
## 从 enemies.json 创建敌人定义；实际关卡阵容由 levels.json 的波次决定。
class_name EnemyDatabase

const DATA_PATH: String = "res://data/enemies.json"

static var _loaded: bool = false
# 每次 create_enemy 都从定义生成新实例，避免奖励和生命跨局残留。
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
	enemy.prototype = str(raw.get("prototype", EnemyData.PROTOTYPE_MASK))
	enemy.description = str(raw.get("description", ""))
	enemy.max_hp = int(raw.get("max_hp", 80))
	enemy.abilities = _parse_abilities(raw.get("abilities", []), enemy.id)
	enemy.toefl_reward = float(raw.get("toefl_reward", 0.0))
	enemy.portrait_path = str(raw.get("portrait_path", ""))
	return enemy


static func _parse_abilities(value: Variant, enemy_id: String) -> Array[EnemyAbilityData]:
	var abilities: Array[EnemyAbilityData] = []
	if not value is Array:
		push_error("EnemyDatabase: abilities for '%s' must be an array." % enemy_id)
		return abilities
	for raw_value: Variant in value as Array:
		if not raw_value is Dictionary:
			continue
		var raw: Dictionary = raw_value as Dictionary
		var ability: EnemyAbilityData = EnemyAbilityData.new()
		ability.id = str(raw.get("id", ""))
		ability.power = int(raw.get("power", 0))
		ability.weight = float(raw.get("weight", 1.0))
		if ability.id.is_empty():
			push_error("EnemyDatabase: enemy '%s' has an ability without an id." % enemy_id)
			continue
		abilities.append(ability)
	return abilities


static func reload() -> void:
	_loaded = false
	_definitions.clear()
	_ensure_loaded()


static func _ensure_loaded() -> void:
	# 数据首次使用时加载并校验重复 ID。
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

	var root_data: Dictionary = parsed as Dictionary
	var enemies_value: Variant = root_data.get("enemies")
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
