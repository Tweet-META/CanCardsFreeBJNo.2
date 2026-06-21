extends Control
## 双方共用的护盾表现，同时支持固定护盾值与百分比减伤。
class_name ShieldVisual

@onready var shield_label: Label = $ShieldLabel


func setup(fixed_shield: int, damage_reduction: float) -> void:
	var safe_shield: int = maxi(0, fixed_shield)
	var safe_reduction: float = clampf(damage_reduction, 0.0, 1.0)
	visible = safe_shield > 0 or safe_reduction > 0.0
	if not visible:
		shield_label.text = ""
		return

	var values: Array[String] = []
	if safe_shield > 0:
		values.append(str(safe_shield))
	if safe_reduction > 0.0:
		values.append("%d%%" % roundi(safe_reduction * 100.0))
	shield_label.text = " | ".join(values)

