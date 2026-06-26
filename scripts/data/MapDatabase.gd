extends RefCounted
## 从 maps.json 加载可扩展地图列表，并为地图场景创建独立数据实例。
class_name MapDatabase

const DATA_PATH: String = "res://data/maps.json"

static var _loaded: bool = false
static var _default_map_id: String = ""
static var _map_order: Array[String] = []
static var _definitions: Dictionary = {}


## 创建所有地图数据，并保留 JSON 中的显示顺序。
static func get_maps() -> Array[MapData]:
	_ensure_loaded()
	var maps: Array[MapData] = []
	for map_id: String in _map_order:
		var map_data: MapData = create_map(map_id)
		if map_data != null:
			maps.append(map_data)
	return maps


## 在当前地图列表中查找默认地图的下标。
static func get_default_map_index(maps: Array[MapData]) -> int:
	for index in maps.size():
		if maps[index].id == _default_map_id:
			return index
	return 0


## 按地图 ID 创建一份新的 MapData 实例。
static func create_map(map_id: String) -> MapData:
	_ensure_loaded()
	var raw_value: Variant = _definitions.get(map_id)
	if not raw_value is Dictionary:
		push_error("MapDatabase: unknown map id '%s'." % map_id)
		return null

	var raw: Dictionary = raw_value as Dictionary
	var map_data: MapData = MapData.new()
	map_data.id = str(raw.get("id", ""))
	map_data.display_name = str(raw.get("display_name", ""))
	map_data.image_path = str(raw.get("image_path", ""))
	map_data.unlocked = bool(raw.get("unlocked", false))
	map_data.level_ids = _to_string_array(raw.get("levels", []))
	return map_data


## 清空缓存并重新读取 maps.json。
static func reload() -> void:
	_loaded = false
	_default_map_id = ""
	_map_order.clear()
	_definitions.clear()
	_ensure_loaded()


## 延迟读取 maps.json，并建立 ID 到原始字典的索引。
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
	_default_map_id = str(root_data.get("default_map", ""))
	var maps_value: Variant = root_data.get("maps", [])
	if not maps_value is Array:
		push_error("MapDatabase: maps must be an array.")
		return

	for raw_value: Variant in maps_value as Array:
		if not raw_value is Dictionary:
			continue
		var raw: Dictionary = raw_value as Dictionary
		var map_id: String = str(raw.get("id", ""))
		if map_id.is_empty():
			push_error("MapDatabase: map definition is missing an id.")
			continue
		if _definitions.has(map_id):
			push_error("MapDatabase: duplicate map id '%s'." % map_id)
			continue
		_definitions[map_id] = raw
		_map_order.append(map_id)


## 把 JSON 数组安全转换为字符串数组。
static func _to_string_array(value: Variant) -> Array[String]:
	var result: Array[String] = []
	if not value is Array:
		return result
	for item: Variant in value as Array:
		result.append(str(item))
	return result
