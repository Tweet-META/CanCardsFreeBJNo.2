extends Resource
## 单个持续性效果的运行时数据；静态文案和图标来自 effects.json。
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
	# 同一来源的同名效果不叠层，保留较强数值并刷新为较长持续时间。
	value = maxf(value, effect_value)
	remaining_turns = maxi(remaining_turns, duration)


func get_stack_key() -> String:
	# 来源 ID 参与叠加键；无来源效果仍按 effect ID 作为单一实例处理。
	return "%s::%s" % [id, source_id]


func is_active() -> bool:
	return delay_turns <= 0 and remaining_turns > 0


func advance_turn() -> bool:
	if not advances_with_turn:
		return false
	# 延迟结束的当回合开始生效，不在同一次推进中扣除持续时间。
	if delay_turns > 0:
		delay_turns -= 1
		return false
	remaining_turns = maxi(0, remaining_turns - 1)
	return remaining_turns <= 0
