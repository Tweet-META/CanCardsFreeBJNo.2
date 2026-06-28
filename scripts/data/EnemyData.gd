extends Resource
## Defines the EnemyData script.
class_name EnemyData

const PROTOTYPE_BUN: String = "bun"
const PROTOTYPE_SLIME: String = "slime"
const PROTOTYPE_MASK: String = "mask"
const PROTOTYPE_NIAN: String = "nian"

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
var charge_ability_id: String = ""
var charge_power: int = 0
var charge_remaining_turns: int = 0
var charge_target_index: int = -1
var charge_target_name: String = ""
var charge_target_portrait_path: String = ""


func setup_runtime() -> void:
	current_hp = max_hp
	current_shield = 0
	damage_reduction = 0.0
	rewards_collected = false
	active_effects.clear()
	clear_charge()


func is_alive() -> bool:
	return current_hp > 0


func is_charging() -> bool:
	return not charge_ability_id.is_empty() and charge_remaining_turns > 0 and charge_target_index >= 0


func start_charge(
	ability_id: String,
	power: int,
	target_index: int,
	wait_turns: int,
	target_name: String = "",
	target_portrait_path: String = ""
) -> void:
	charge_ability_id = ability_id
	charge_power = maxi(0, power)
	charge_target_index = target_index
	charge_remaining_turns = maxi(0, wait_turns)
	charge_target_name = target_name
	charge_target_portrait_path = target_portrait_path


func advance_charge() -> int:
	charge_remaining_turns = maxi(0, charge_remaining_turns - 1)
	return charge_remaining_turns


func clear_charge() -> void:
	charge_ability_id = ""
	charge_power = 0
	charge_remaining_turns = 0
	charge_target_index = -1
	charge_target_name = ""
	charge_target_portrait_path = ""


func take_damage(raw_damage: int) -> int:
	var incoming_damage: int = roundi(float(maxi(0, raw_damage)) * get_incoming_damage_multiplier())
	var reduced_damage: int = roundi(float(incoming_damage) * (1.0 - clampf(damage_reduction, 0.0, 0.85)))
	var absorbed_damage: int = mini(current_shield, reduced_damage)
	current_shield -= absorbed_damage
	var health_damage: int = reduced_damage - absorbed_damage
	current_hp = maxi(0, current_hp - health_damage)
	return health_damage


func add_shield(amount: int) -> int:
	var gained_shield: int = maxi(0, amount)
	current_shield += gained_shield
	return gained_shield


func add_damage_reduction(amount: float) -> void:
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
	var multiplier: float = 1.0
	for effect: StatusEffectData in active_effects:
		if effect.is_active() and effect.id == "vulnerable":
			multiplier *= 1.0 + effect.value
	return maxf(multiplier, 0.0)


func advance_status_effect_turns() -> void:
	for i in range(active_effects.size() - 1, -1, -1):
		if active_effects[i].advance_turn():
			active_effects.remove_at(i)


func choose_ability(rng: RandomNumberGenerator) -> EnemyAbilityData:
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
