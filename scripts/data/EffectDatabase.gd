extends RefCounted
## Defines the EffectDatabase script.
class_name EffectDatabase

const DATA_PATH: String = "res://data/effects.json"

static var _loaded: bool = false
static var _definitions: Dictionary = {}


static func create_effect(
	effect_id: String,
	value: float,
	duration: int,
	source_id: String = "",
	source_name: String = "",
	delay_turns: int = 0
) -> StatusEffectData:
	_ensure_loaded()
	var raw_value: Variant = _definitions.get(effect_id)
	if not raw_value is Dictionary:
		push_error("EffectDatabase: unknown effect id '%s'." % effect_id)
		return null

	var raw: Dictionary = raw_value as Dictionary
	var effect: StatusEffectData = StatusEffectData.new()
	effect.id = str(raw.get("id", ""))
	effect.display_name = str(raw.get("display_name", ""))
	effect.description = str(raw.get("description", ""))
	effect.icon_path = str(raw.get("icon_path", ""))
	effect.value_format = str(raw.get("value_format", "none"))
	effect.show_duration = bool(raw.get("show_duration", true))
	effect.advances_with_turn = bool(raw.get("advances_with_turn", true))
	effect.setup_runtime(value, duration, source_id, source_name, delay_turns)
	return effect


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
		push_error("EffectDatabase: could not open %s." % DATA_PATH)
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if not parsed is Dictionary:
		push_error("EffectDatabase: %s must contain a JSON object." % DATA_PATH)
		return

	var effects_value: Variant = (parsed as Dictionary).get("effects")
	if not effects_value is Array:
		push_error("EffectDatabase: effects must be an array.")
		return
	for raw_value: Variant in effects_value as Array:
		if not raw_value is Dictionary:
			continue
		var raw: Dictionary = raw_value as Dictionary
		var effect_id: String = str(raw.get("id", ""))
		if effect_id.is_empty():
			push_error("EffectDatabase: effect definition is missing an id.")
			continue
		if _definitions.has(effect_id):
			push_error("EffectDatabase: duplicate effect id '%s'." % effect_id)
			continue
		_definitions[effect_id] = raw
