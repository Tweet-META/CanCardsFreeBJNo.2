extends RefCounted
## 从 maps.json 加载可扩展楼层列表，并为地图场景创建独立数据实例。
class_name MapDatabase

const DATA_PATH: String = "res://data/maps.json"

static var _loaded: bool = false
static var _default_floor_id: String = ""
static var _floor_order: Array[String] = []
static var _definitions: Dictionary = {}


static func get_floors() -> Array[MapFloorData]:
	_ensure_loaded()
	var floors: Array[MapFloorData] = []
	for floor_id: String in _floor_order:
		var floor: MapFloorData = create_floor(floor_id)
		if floor != null:
			floors.append(floor)
	return floors


static func get_default_floor_index(floors: Array[MapFloorData]) -> int:
	for index in floors.size():
		if floors[index].id == _default_floor_id:
			return index
	return 0


static func create_floor(floor_id: String) -> MapFloorData:
	_ensure_loaded()
	var raw_value: Variant = _definitions.get(floor_id)
	if not raw_value is Dictionary:
		push_error("MapDatabase: unknown floor id '%s'." % floor_id)
		return null

	var raw: Dictionary = raw_value as Dictionary
	var floor: MapFloorData = MapFloorData.new()
	floor.id = str(raw.get("id", ""))
	floor.display_name = str(raw.get("display_name", ""))
	floor.image_path = str(raw.get("image_path", ""))
	floor.unlocked = bool(raw.get("unlocked", false))
	floor.stage_ids = _to_string_array(raw.get("stages", []))
	return floor


static func reload() -> void:
	_loaded = false
	_default_floor_id = ""
	_floor_order.clear()
	_definitions.clear()
	_ensure_loaded()


static func _ensure_loaded() -> void:
	if _loaded:
		return
	_loaded = true

	var file: FileAccess = FileAccess.open(DATA_PATH, FileAccess.READ)
	if file == null:
		push_error("MapDatabase: could not open %s." % DATA_PATH)
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if not parsed is Dictionary:
		push_error("MapDatabase: %s must contain a JSON object." % DATA_PATH)
		return

	var root_data: Dictionary = parsed as Dictionary
	_default_floor_id = str(root_data.get("default_floor", ""))
	var floors_value: Variant = root_data.get("floors", [])
	if not floors_value is Array:
		push_error("MapDatabase: floors must be an array.")
		return

	for raw_value: Variant in floors_value as Array:
		if not raw_value is Dictionary:
			continue
		var raw: Dictionary = raw_value as Dictionary
		var floor_id: String = str(raw.get("id", ""))
		if floor_id.is_empty():
			push_error("MapDatabase: floor definition is missing an id.")
			continue
		if _definitions.has(floor_id):
			push_error("MapDatabase: duplicate floor id '%s'." % floor_id)
			continue
		_definitions[floor_id] = raw
		_floor_order.append(floor_id)


static func _to_string_array(value: Variant) -> Array[String]:
	var result: Array[String] = []
	if not value is Array:
		return result
	for item: Variant in value as Array:
		result.append(str(item))
	return result
