extends RefCounted
## 从 levels.json 创建关卡数据，并供地图按 ID 获取关卡定义。
class_name LevelDatabase

const DATA_PATH: String = "res://data/levels.json"

static var _loaded: bool = false
static var _definitions: Dictionary = {}
static var _active_level_id: String = "level1"


## 按关卡 ID 创建一份新的 LevelData 实例。
static func create_level(level_id: String) -> LevelData:
	_ensure_loaded()
	var raw_value: Variant = _definitions.get(level_id)
	if not raw_value is Dictionary:
		push_error("LevelDatabase: unknown level id '%s'." % level_id)
		return null

	var raw: Dictionary = raw_value as Dictionary
	var level: LevelData = LevelData.new()
	level.id = str(raw.get("id", ""))
	level.display_name = str(raw.get("display_name", ""))
	level.marker_text = str(raw.get("marker_text", ""))
	level.map_id = str(raw.get("map_id", ""))
	level.map_position = _parse_position(raw.get("map_position", [0.5, 0.5]))
	level.scene_path = str(raw.get("scene_path", ""))
	level.battle_background = str(raw.get("battle_background", ""))
	level.waves = _parse_waves(raw.get("wave", []), level.id)
	level.unlocked = bool(raw.get("unlocked", false))
	return level


## 记录地图选中的关卡，供 BattleManager 进入战斗时读取。
static func set_active_level(level_id: String) -> void:
	_ensure_loaded()
	if not _definitions.has(level_id):
		push_error("LevelDatabase: cannot activate unknown level '%s'." % level_id)
		return
	_active_level_id = level_id


## 创建当前被地图激活的关卡数据。
static func get_active_level() -> LevelData:
	return create_level(_active_level_id)


## 按一组关卡 ID 创建关卡列表，忽略无效 ID。
static func create_levels(level_ids: Array[String]) -> Array[LevelData]:
	var levels: Array[LevelData] = []
	for level_id: String in level_ids:
		var level: LevelData = create_level(level_id)
		if level != null:
			levels.append(level)
	return levels


## 清空缓存并重新读取 levels.json。
static func reload() -> void:
	_loaded = false
	_definitions.clear()
	_ensure_loaded()


## 延迟读取 levels.json，并建立 ID 到原始字典的索引。
static func _ensure_loaded() -> void:
	if _loaded:
		return
	_loaded = true

	var file: FileAccess = FileAccess.open(DATA_PATH, FileAccess.READ)
	if file == null:
		push_error("LevelDatabase: could not open %s." % DATA_PATH)
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if not parsed is Dictionary:
		push_error("LevelDatabase: %s must contain a JSON object." % DATA_PATH)
		return

	var root_data: Dictionary = parsed as Dictionary
	var levels_value: Variant = root_data.get("levels", [])
	if not levels_value is Array:
		push_error("LevelDatabase: levels must be an array.")
		return
	for raw_value: Variant in levels_value as Array:
		if not raw_value is Dictionary:
			continue
		var raw: Dictionary = raw_value as Dictionary
		var level_id: String = str(raw.get("id", ""))
		if level_id.is_empty():
			push_error("LevelDatabase: level definition is missing an id.")
			continue
		if _definitions.has(level_id):
			push_error("LevelDatabase: duplicate level id '%s'." % level_id)
			continue
		_definitions[level_id] = raw


## 把 JSON 中的归一化坐标解析为 Vector2。
static func _parse_position(value: Variant) -> Vector2:
	if not value is Array:
		return Vector2(0.5, 0.5)
	var values: Array = value as Array
	if values.size() < 2:
		return Vector2(0.5, 0.5)
	return Vector2(clampf(float(values[0]), 0.0, 1.0), clampf(float(values[1]), 0.0, 1.0))


## 解析关卡波次，并把每个 monster 位置转换为候选怪物槽。
static func _parse_waves(value: Variant, level_id: String) -> Array[LevelWaveData]:
	var waves: Array[LevelWaveData] = []
	if not value is Array:
		push_error("LevelDatabase: wave for '%s' must be an array." % level_id)
		return waves
	for wave_value: Variant in value as Array:
		if not wave_value is Dictionary:
			continue
		var wave_raw: Dictionary = wave_value as Dictionary
		var monster_value: Variant = wave_raw.get("monster", [])
		if not monster_value is Array:
			push_error("LevelDatabase: monster for '%s' must be an array." % level_id)
			continue
		var wave: LevelWaveData = LevelWaveData.new()
		for slot_value: Variant in monster_value as Array:
			var candidates: Array[String] = _to_string_array(slot_value)
			if candidates.is_empty():
				continue
			var slot: MonsterSlotData = MonsterSlotData.new()
			slot.candidate_enemy_ids = candidates
			wave.monster_slots.append(slot)
		waves.append(wave)
	return waves


## 把 JSON 数组安全转换为字符串数组。
static func _to_string_array(value: Variant) -> Array[String]:
	var result: Array[String] = []
	if not value is Array:
		return result
	for item: Variant in value as Array:
		result.append(str(item))
	return result
