extends RefCounted
## 从 stages.json 创建关卡数据，并供地图按 ID 获取关卡定义。
class_name StageDatabase

const DATA_PATH: String = "res://data/stages.json"

static var _loaded: bool = false
static var _definitions: Dictionary = {}
static var _active_stage_id: String = "first_stage"


static func create_stage(stage_id: String) -> StageData:
	_ensure_loaded()
	var raw_value: Variant = _definitions.get(stage_id)
	if not raw_value is Dictionary:
		push_error("StageDatabase: unknown stage id '%s'." % stage_id)
		return null

	var raw: Dictionary = raw_value as Dictionary
	var stage: StageData = StageData.new()
	stage.id = str(raw.get("id", ""))
	stage.display_name = str(raw.get("display_name", ""))
	stage.description = str(raw.get("description", ""))
	stage.marker_text = str(raw.get("marker_text", ""))
	stage.floor_id = str(raw.get("floor_id", ""))
	stage.map_position = _parse_position(raw.get("map_position", [0.5, 0.5]))
	stage.scene_path = str(raw.get("scene_path", ""))
	stage.battle_background = str(raw.get("battle_background", ""))
	stage.waves = _parse_waves(raw.get("wave", []), stage.id)
	stage.unlocked = bool(raw.get("unlocked", false))
	return stage


static func set_active_stage(stage_id: String) -> void:
	_ensure_loaded()
	if not _definitions.has(stage_id):
		push_error("StageDatabase: cannot activate unknown stage '%s'." % stage_id)
		return
	_active_stage_id = stage_id


static func get_active_stage() -> StageData:
	return create_stage(_active_stage_id)


static func create_stages(stage_ids: Array[String]) -> Array[StageData]:
	var stages: Array[StageData] = []
	for stage_id: String in stage_ids:
		var stage: StageData = create_stage(stage_id)
		if stage != null:
			stages.append(stage)
	return stages


static func reload() -> void:
	_loaded = false
	_definitions.clear()
	_ensure_loaded()


static func _ensure_loaded() -> void:
	if _loaded:
		return
	_loaded = true

	var file: FileAccess = FileAccess.open(DATA_PATH, FileAccess.READ)
	if file == null:
		push_error("StageDatabase: could not open %s." % DATA_PATH)
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if not parsed is Dictionary:
		push_error("StageDatabase: %s must contain a JSON object." % DATA_PATH)
		return

	var root_data: Dictionary = parsed as Dictionary
	var stages_value: Variant = root_data.get("stages", [])
	if not stages_value is Array:
		push_error("StageDatabase: stages must be an array.")
		return
	for raw_value: Variant in stages_value as Array:
		if not raw_value is Dictionary:
			continue
		var raw: Dictionary = raw_value as Dictionary
		var stage_id: String = str(raw.get("id", ""))
		if stage_id.is_empty():
			push_error("StageDatabase: stage definition is missing an id.")
			continue
		if _definitions.has(stage_id):
			push_error("StageDatabase: duplicate stage id '%s'." % stage_id)
			continue
		_definitions[stage_id] = raw


static func _parse_position(value: Variant) -> Vector2:
	if not value is Array:
		return Vector2(0.5, 0.5)
	var values: Array = value as Array
	if values.size() < 2:
		return Vector2(0.5, 0.5)
	return Vector2(clampf(float(values[0]), 0.0, 1.0), clampf(float(values[1]), 0.0, 1.0))


static func _parse_waves(value: Variant, stage_id: String) -> Array[StageWaveData]:
	var waves: Array[StageWaveData] = []
	if not value is Array:
		push_error("StageDatabase: wave for '%s' must be an array." % stage_id)
		return waves
	for wave_value: Variant in value as Array:
		if not wave_value is Dictionary:
			continue
		var wave_raw: Dictionary = wave_value as Dictionary
		var monster_value: Variant = wave_raw.get("monster", [])
		if not monster_value is Array:
			push_error("StageDatabase: monster for '%s' must be an array." % stage_id)
			continue
		var wave: StageWaveData = StageWaveData.new()
		for slot_value: Variant in monster_value as Array:
			var candidates: Array[String] = _to_string_array(slot_value)
			if candidates.is_empty():
				continue
			var slot: MonsterSlotData = MonsterSlotData.new()
			slot.candidate_enemy_ids = candidates
			wave.monster_slots.append(slot)
		waves.append(wave)
	return waves


static func _to_string_array(value: Variant) -> Array[String]:
	var result: Array[String] = []
	if not value is Array:
		return result
	for item: Variant in value as Array:
		result.append(str(item))
	return result
