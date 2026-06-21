extends Resource
## 我方角色的静态资料与单局运行状态；队伍共享 AP 存放在 BattleState。
class_name CharacterData

@export var id: String = ""
@export var display_name: String = ""
@export var attribute: String = ""
@export var description: String = ""
@export var max_hp: int = 100
@export var portrait_path: String = ""
@export var cards: Array[CardData] = []

var base_max_hp: int = 0
# 以下字段只在当前战斗中变化，不写回 JSON。
var current_hp: int = 100
var has_acted: bool = false
var current_shield: int = 0
var turn_damage_reduction: float = 0.0


func setup_runtime(max_hp_multiplier: float = 1.0) -> void:
	# base_max_hp 防止重开战斗时重复把拼音生命加成乘到已放大的 max_hp 上。
	if base_max_hp <= 0:
		base_max_hp = max_hp
	max_hp = maxi(1, roundi(float(base_max_hp) * maxf(max_hp_multiplier, 0.0)))
	current_hp = max_hp
	has_acted = false
	current_shield = 0
	turn_damage_reduction = 0.0


func is_alive() -> bool:
	return current_hp > 0


func heal(amount: int) -> void:
	current_hp = mini(max_hp, current_hp + maxi(amount, 0))


func take_damage(raw_damage: int, incoming_attribute: String = "") -> int:
	# 百分比减伤先结算，再由固定护盾吸收，最后扣除生命。
	var reduction: float = turn_damage_reduction
	if incoming_attribute == attribute:
		reduction += 0.20

	var reduced_damage: int = maxi(1, roundi(float(raw_damage) * (1.0 - clampf(reduction, 0.0, 0.85))))
	var absorbed_damage: int = mini(current_shield, reduced_damage)
	current_shield -= absorbed_damage
	var health_damage: int = reduced_damage - absorbed_damage
	current_hp = maxi(0, current_hp - health_damage)
	return health_damage


func reset_turn_state() -> void:
	has_acted = false
	turn_damage_reduction = 0.0


func mark_acted() -> void:
	has_acted = true


func add_turn_damage_reduction(amount: float) -> void:
	turn_damage_reduction = clampf(turn_damage_reduction + amount, 0.0, 0.85)


func add_shield(amount: int) -> int:
	# 固定护盾可以叠加，并在受击吸收完毕后自然归零。
	var gained_shield: int = maxi(0, amount)
	current_shield += gained_shield
	return gained_shield
