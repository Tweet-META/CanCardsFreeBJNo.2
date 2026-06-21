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
var active_effects: Array[StatusEffectData] = []
var last_damage_was_immune: bool = false


func setup_runtime(max_hp_multiplier: float = 1.0) -> void:
	# base_max_hp 防止重开战斗时重复把拼音生命加成乘到已放大的 max_hp 上。
	if base_max_hp <= 0:
		base_max_hp = max_hp
	max_hp = maxi(1, roundi(float(base_max_hp) * maxf(max_hp_multiplier, 0.0)))
	current_hp = max_hp
	has_acted = false
	current_shield = 0
	turn_damage_reduction = 0.0
	active_effects.clear()
	last_damage_was_immune = false


func is_alive() -> bool:
	return current_hp > 0


func heal(amount: int) -> int:
	var hp_before: int = current_hp
	current_hp = mini(max_hp, current_hp + maxi(amount, 0))
	return current_hp - hp_before


func take_damage(raw_damage: int, incoming_attribute: String = "") -> int:
	# 首次伤害免疫优先于减伤和护盾结算，并在触发后立即消耗一个实例。
	last_damage_was_immune = false
	if raw_damage > 0 and consume_status_effect("damage_immunity"):
		last_damage_was_immune = true
		return 0

	var amplified_damage: int = roundi(float(raw_damage) * get_incoming_damage_multiplier())
	var reduction: float = turn_damage_reduction
	if incoming_attribute == attribute:
		reduction += 0.20

	var reduced_damage: int = maxi(1, roundi(float(amplified_damage) * (1.0 - clampf(reduction, 0.0, 0.85))))
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


func apply_status_effect(effect: StatusEffectData) -> void:
	if effect == null or effect.id.is_empty():
		return
	if effect.id == "damage_immunity":
		var immunity: StatusEffectData = get_status_effect("damage_immunity")
		if immunity != null:
			immunity.value += maxf(effect.value, 1.0)
			return
	var existing: StatusEffectData = get_status_effect_from_source(effect.id, effect.source_id)
	if existing != null:
		existing.refresh(effect.value, effect.remaining_turns)
		return
	active_effects.append(effect)


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


func get_status_effect_from_card(effect_id: String, card_id: String) -> StatusEffectData:
	var source_suffix: String = "::%s" % card_id
	for effect: StatusEffectData in active_effects:
		if effect.id == effect_id and effect.source_id.ends_with(source_suffix):
			return effect
	return null


func consume_status_effect(effect_id: String) -> bool:
	for i in active_effects.size():
		if active_effects[i].id == effect_id:
			if effect_id == "damage_immunity" and active_effects[i].value > 1.0:
				active_effects[i].value -= 1.0
			else:
				active_effects.remove_at(i)
			return true
	return false


func get_outgoing_damage_multiplier() -> float:
	var multiplier: float = 1.0
	for effect: StatusEffectData in active_effects:
		if not effect.is_active():
			continue
		if effect.id == "weakness":
			multiplier *= maxf(0.0, 1.0 - effect.value)
		elif effect.id == "strength":
			multiplier *= 1.0 + effect.value
	return multiplier


func get_incoming_damage_multiplier() -> float:
	var multiplier: float = 1.0
	for effect: StatusEffectData in active_effects:
		if effect.is_active() and effect.id == "vulnerable":
			multiplier *= 1.0 + effect.value
	return multiplier


func advance_status_effect_turns() -> void:
	for i in range(active_effects.size() - 1, -1, -1):
		if active_effects[i].advance_turn():
			active_effects.remove_at(i)


func lose_hp_direct(amount: int) -> int:
	# 直接扣血不触发伤害免疫、减伤或护盾。
	var lost_hp: int = mini(current_hp, maxi(amount, 0))
	current_hp -= lost_hp
	return lost_hp
