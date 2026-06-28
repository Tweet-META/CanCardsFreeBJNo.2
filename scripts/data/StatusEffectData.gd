extends Resource
## Defines the StatusEffectData script.
class_name StatusEffectData

@export var id: String = ""
@export var display_name: String = ""
@export_multiline var description: String = ""
@export var icon_path: String = ""
@export var value_format: String = "none"
@export var show_duration: bool = true
@export var advances_with_turn: bool = true

var value: float = 0.0
var remaining_turns: int = 0
var delay_turns: int = 0
var source_id: String = ""
var source_name: String = ""


func setup_runtime(
	effect_value: float,
	duration: int,
	effect_source_id: String = "",
	effect_source_name: String = "",
	effect_delay_turns: int = 0
) -> void:
	value = maxf(effect_value, 0.0)
	remaining_turns = maxi(duration, 0)
	delay_turns = maxi(effect_delay_turns, 0)
	source_id = effect_source_id
	source_name = effect_source_name


func refresh(effect_value: float, duration: int) -> void:
	value = maxf(value, effect_value)
	remaining_turns = maxi(remaining_turns, duration)


func get_stack_key() -> String:
	return "%s::%s" % [id, source_id]


func is_active() -> bool:
	return delay_turns <= 0 and remaining_turns > 0


func advance_turn() -> bool:
	if not advances_with_turn:
		return false
	if delay_turns > 0:
		delay_turns -= 1
		return false
	remaining_turns = maxi(0, remaining_turns - 1)
	return remaining_turns <= 0
