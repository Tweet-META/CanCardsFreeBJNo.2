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
var active_effects: Array[StatusEffectData] = []


func setup_runtime() -> void:
	current_hp = max_hp
	current_shield = 0
	damage_reduction = 0.0
	rewards_collected = false
	active_effects.clear()


func is_alive() -> bool:
	return current_hp > 0


func take_damage(raw_damage: int) -> int:
	# 易伤先放大来袭伤害，再结算百分比减伤、固定护盾和生命值。
	var incoming_damage: int = roundi(float(maxi(0, raw_damage)) * get_incoming_damage_multiplier())
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


func apply_status_effect(effect: StatusEffectData) -> bool:
	if effect == null or effect.id.is_empty() or effect.remaining_turns <= 0:
		return false
	if effect.id == "stun" and get_status_effect("stun") != null:
		return false
	var existing: StatusEffectData = get_status_effect_from_source(effect.id, effect.source_id)
	if existing != null:
		existing.refresh(effect.value, effect.remaining_turns)
		return true
	active_effects.append(effect)
	return true


func get_status_effect(effect_id: String) -> StatusEffectData:
	# 兼容只关心效果类型的查询；存在多来源时返回第一项。
	for effect: StatusEffectData in active_effects:
		if effect.id == effect_id:
			return effect
	return null


func get_status_effect_from_source(effect_id: String, source_id: String) -> StatusEffectData:
	var stack_key: String = "%s::%s" % [effect_id, source_id]
	for effect: StatusEffectData in active_effects:
		if effect.get_stack_key() == stack_key:
			return effect
	return null


func consume_all_status_effects(effect_id: String) -> int:
	var consumed_count: int = 0
	for i in range(active_effects.size() - 1, -1, -1):
		if active_effects[i].id == effect_id:
			active_effects.remove_at(i)
			consumed_count += 1
	return consumed_count


func get_incoming_damage_multiplier() -> float:
	# 不同来源的易伤按乘算叠加，例如两份 20% 易伤为 1.2 × 1.2。
	var multiplier: float = 1.0
	for effect: StatusEffectData in active_effects:
		if effect.is_active() and effect.id == "vulnerable":
			multiplier *= 1.0 + effect.value
	return maxf(multiplier, 0.0)


func advance_status_effect_turns() -> void:
	# 从后向前删除到期效果，避免移除元素后跳过下一项。
	for i in range(active_effects.size() - 1, -1, -1):
		if active_effects[i].advance_turn():
			active_effects.remove_at(i)


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
