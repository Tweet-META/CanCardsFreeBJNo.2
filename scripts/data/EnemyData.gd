extends Resource
## 敌人的静态资料与单局生命、护盾状态；原型决定其敌方回合行为。
class_name EnemyData

const PROTOTYPE_BUN: String = "bun"
const PROTOTYPE_SLIME: String = "slime"
const PROTOTYPE_MASK: String = "mask"

@export var id: String = ""
@export var display_name: String = ""
@export var attribute: String = ""
@export var prototype: String = PROTOTYPE_MASK
@export var description: String = ""
@export var max_hp: int = 80
@export var abilities: Array[EnemyAbilityData] = []
@export var toefl_reward: float = 1.0
@export var portrait_path: String = ""

var current_hp: int = 80
var current_shield: int = 0
var damage_reduction: float = 0.0
var rewards_collected: bool = false


func setup_runtime() -> void:
	current_hp = max_hp
	current_shield = 0
	damage_reduction = 0.0
	rewards_collected = false


func is_alive() -> bool:
	return current_hp > 0


func take_damage(raw_damage: int) -> int:
	# 百分比减伤先结算，再由固定护盾吸收，最后扣除生命。
	var incoming_damage: int = maxi(0, raw_damage)
	var reduced_damage: int = roundi(float(incoming_damage) * (1.0 - clampf(damage_reduction, 0.0, 0.85)))
	var absorbed_damage: int = mini(current_shield, reduced_damage)
	current_shield -= absorbed_damage
	var health_damage: int = reduced_damage - absorbed_damage
	current_hp = maxi(0, current_hp - health_damage)
	return health_damage


func add_shield(amount: int) -> int:
	# 返回实际增加值，供战斗日志与后续状态表现使用。
	var gained_shield: int = maxi(0, amount)
	current_shield += gained_shield
	return gained_shield


func add_damage_reduction(amount: float) -> void:
	# 为未来敌方百分比护盾技能提供统一入口，当前上限与我方一致。
	damage_reduction = clampf(damage_reduction + amount, 0.0, 0.85)


func choose_ability(rng: RandomNumberGenerator) -> EnemyAbilityData:
	# 非正权重技能不会被选择；全部权重无效时回退第一项，避免敌方回合中断。
	if abilities.is_empty():
		return null
	var total_weight: float = 0.0
	for ability: EnemyAbilityData in abilities:
		total_weight += maxf(ability.weight, 0.0)
	if total_weight <= 0.0:
		return abilities[0]

	var roll: float = rng.randf() * total_weight
	var accumulated_weight: float = 0.0
	for ability: EnemyAbilityData in abilities:
		accumulated_weight += maxf(ability.weight, 0.0)
		if roll < accumulated_weight:
			return ability
	return abilities[-1]
