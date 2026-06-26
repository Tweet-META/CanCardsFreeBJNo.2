extends Node
## 战斗规则与回合状态机；通过 signal 通知 UI，不直接操作界面节点。
class_name BattleManager

signal state_changed(state: BattleState)
signal difficulty_requested()
signal question_requested(question: QuestionData)
signal result_requested(title: String, message: String, battle_over: bool, victory: bool)
signal log_added(message: String)

var state: BattleState = BattleState.new()
var question_bank: QuestionBank = QuestionBank.new()
var rng: RandomNumberGenerator = RandomNumberGenerator.new()
var active_level: LevelData

const TEAM_GENERAL_CARD_INDEX_OFFSET: int = 1000


## 初始化随机数并开始当前激活关卡的战斗。
func _ready() -> void:
	rng.randomize()
	start_new_battle()


## 使用 LevelDatabase 当前激活关卡创建一场新战斗。
func start_new_battle() -> void:
	# 所有关卡共用本场景，地图选择的 level_id 决定背景与全部波次。
	_start_battle_with_level(LevelDatabase.get_active_level())


## 按关卡数据初始化玩家队伍、第一波敌人、商店和首个玩家回合。
func _start_battle_with_level(level: LevelData) -> void:
	active_level = level
	if active_level == null or active_level.waves.is_empty():
		push_error("BattleManager: active level has no waves.")
		return
	var first_wave: Array[EnemyData] = GameDataFactory.create_level_wave(active_level, 0, rng)
	state.setup(GameDataFactory.create_player_team(), first_wave, active_level, rng)
	_roll_shop_offers()
	state.push_log(tr("LOG_BATTLE_START"))
	_emit_log(tr("LOG_WAVE_START") % [state.current_wave, state.total_waves])
	state.start_player_turn()
	_emit_log(tr("LOG_PLAYER_TURN_START") % state.turn_count)
	state_changed.emit(state)


## 接收 UI 出牌请求，验证阶段、行动资格、AP 和目标后进入结算或答题。
func request_use_card(character_index: int, card_index: int, enemy_index: int, ally_index: int, _difficulty: String = "") -> void:
	# 所有出牌请求的唯一入口：先验证阶段、行动资格、AP 和目标。
	if state.phase != BattleState.Phase.PLAYER_TURN:
		_emit_log(tr("LOG_CANNOT_USE_CARD"))
		return
	if character_index < 0 or character_index >= state.player_team.size():
		return

	var character: CharacterData = state.player_team[character_index]
	if not character.is_alive():
		_emit_log(tr("LOG_CHARACTER_UNAVAILABLE") % tr(character.display_name))
		return
	if character.has_acted:
		_emit_log(tr("LOG_CHARACTER_ACTED") % tr(character.display_name))
		return
	var card: CardData = _get_card_for_request(character, card_index)
	if card == null:
		return

	if not card.can_use(state.ap):
		_emit_log(tr("LOG_CARD_AP_REQUIRED") % [tr(card.display_name), card.skill_ap_cost])
		return

	var target_enemy: EnemyData = _get_enemy_or_first_alive(enemy_index)
	if _card_needs_enemy(card) and target_enemy == null:
		_emit_log(tr("LOG_NO_ENEMY_TARGET"))
		return
	var target_ally: CharacterData = _get_ally_or_actor(ally_index, character)
	if _card_needs_ally(card) and target_ally == null:
		_emit_log(tr("LOG_SELECT_ALLY_TARGET"))
		return

	state.selected_character = character
	state.selected_ally = target_ally
	state.selected_enemy = target_enemy
	state.pending_card = card

	if not card.requires_question:
		_apply_card_effect(false, true)
		_finish_player_action()
		return

	if card.is_skill():
		_begin_question("hard")
		return
	if card.card_type == CardData.CardType.ATTACK or card.card_type == CardData.CardType.DEFENSE:
		state.phase = BattleState.Phase.DIFFICULTY_SELECTION
		difficulty_requested.emit()
		state_changed.emit(state)
		return

	_begin_question("easy")


## 接收玩家选择的攻击/防御题目难度。
func select_question_difficulty(difficulty: String) -> void:
	# 仅在等待选择时接受三种难度，避免重复点击覆盖正在回答的题目。
	if state.phase != BattleState.Phase.DIFFICULTY_SELECTION:
		return
	if difficulty not in ["easy", "medium", "hard"]:
		return
	_begin_question(difficulty)


## 按卡牌规则确定实际难度并抽取一道题。
func _begin_question(difficulty: String) -> void:
	var character: CharacterData = state.selected_character
	var card: CardData = state.pending_card
	if character == null or card == null:
		return
	state.pending_difficulty = card.get_question_difficulty(difficulty)
	state.phase = BattleState.Phase.QUESTION
	state.pending_question = question_bank.get_random_question_by_difficulty(state.pending_difficulty, rng)
	_emit_log(tr("LOG_CARD_QUESTION") % [tr(character.display_name), tr(card.display_name), _difficulty_label(state.pending_difficulty)])
	question_requested.emit(state.pending_question)
	state_changed.emit(state)


## 接收答案索引并根据正确性与词汇补偿触发卡牌效果。
func submit_answer(answer_index: int) -> void:
	# 答错不受处罚；词汇被动可能让本次仍按“加成触发”结算。
	if state.phase != BattleState.Phase.QUESTION or state.pending_question == null:
		return

	var correct: bool = state.pending_question.is_answer_correct(answer_index)
	var bonus_triggered: bool = correct
	if not correct:
		var chance: float = state.get_wrong_answer_bonus_chance()
		bonus_triggered = rng.randf() < chance

	var answer_text: String = tr("RESULT_CORRECT") if correct else tr("RESULT_WRONG")
	if bonus_triggered and not correct:
		answer_text += tr("RESULT_VOCABULARY_TRIGGER")

	_apply_card_effect(correct, bonus_triggered)
	_emit_log(answer_text + ("。" if TranslationServer.get_locale() == "zh_CN" else "."))
	result_requested.emit(answer_text, tr(state.pending_question.explanation), false, false)
	_finish_player_action()


## 重新开始当前激活关卡。
func retry_battle() -> void:
	start_new_battle()


## 处理商店刷新请求并扣除刷新费用。
func request_refresh_shop() -> void:
	if not state.spend_new_toefl(0.5):
		_emit_log(tr("LOG_REFRESH_NO_FUNDS"))
		state_changed.emit(state)
		return
	_roll_shop_offers()
	_emit_log(tr("LOG_SHOP_REFRESHED"))
	state_changed.emit(state)


## 处理购买商店通用卡请求，并把买到的卡加入队伍牌堆。
func request_buy_shop_card(offer_index: int, character_index: int) -> void:
	# character_index 当前只验证有存活角色；购买结果属于整个队伍。
	if offer_index < 0 or offer_index >= state.shop_offer_cards.size():
		return
	if character_index < 0 or character_index >= state.player_team.size():
		return
	var target_character: CharacterData = state.player_team[character_index]
	if not target_character.is_alive():
		_emit_log(tr("LOG_BUY_INVALID_CHARACTER"))
		state_changed.emit(state)
		return

	var offer_card: CardData = state.shop_offer_cards[offer_index]
	if not state.spend_new_toefl(offer_card.shop_price):
		_emit_log(tr("LOG_BUY_NO_FUNDS") % tr(offer_card.display_name))
		state_changed.emit(state)
		return

	var bought_card: CardData = offer_card.duplicate(true) as CardData
	bought_card.id = "%s_bought_%d" % [offer_card.id, Time.get_ticks_msec()]
	bought_card.owner_id = "team"
	state.team_general_cards.append(bought_card)
	_emit_log(tr("LOG_CARD_PURCHASED") % [tr(bought_card.display_name), offer_card.shop_price])
	state_changed.emit(state)


## 处理出售队伍通用卡请求并增加 New TOEFL。
func request_sell_general_card(card_index: int) -> void:
	# 出售只修改队伍共享牌堆和 New TOEFL，不占用任何角色的本回合行动。
	if state.phase != BattleState.Phase.PLAYER_TURN:
		return
	if not _is_team_general_card_index(card_index):
		return
	var team_card_index: int = _decode_team_general_card_index(card_index)
	if team_card_index < 0 or team_card_index >= state.team_general_cards.size():
		return

	var sold_card: CardData = state.team_general_cards[team_card_index]
	var sell_price: float = sold_card.get_sell_price()
	state.team_general_cards.remove_at(team_card_index)
	state.add_new_toefl(sell_price)
	_emit_log(tr("LOG_CARD_SOLD") % [tr(sold_card.display_name), sell_price])
	state_changed.emit(state)


## 开发者模式下向当前波次添加一只文化面具。
func developer_add_culture_mask() -> void:
	if not SettingsManager.developer_mode:
		return
	if state.get_alive_enemies().size() >= 8:
		_emit_log(tr("DEV_LOG_ENEMY_LIMIT"))
		return

	var enemy: EnemyData = GameDataFactory.create_culture_mask_enemy()
	enemy.id = "%s_dev_%d" % [enemy.id, Time.get_ticks_msec()]
	enemy.setup_runtime()
	state.enemy_team.append(enemy)
	_emit_log(tr("DEV_LOG_ADDED_MASK"))
	state_changed.emit(state)


## 开发者模式下给队伍添加一张测试通用卡。
func developer_add_general_card() -> void:
	if not SettingsManager.developer_mode:
		return
	var card: CardData = GameDataFactory.create_potion_of_confucius()
	card.id = "%s_dev_%d" % [card.id, Time.get_ticks_msec()]
	card.owner_id = "team"
	state.team_general_cards.append(card)
	_emit_log(tr("DEV_LOG_ADDED_CARD"))
	state_changed.emit(state)


## 授予隐藏彩蛋卡 six_seven。
func grant_six_seven() -> void:
	# 彩蛋卡不进入随机池，只能由开发者工具或战斗中的数字口令授予。
	var card: CardData = GameDataFactory.create_six_seven()
	if card == null:
		return
	card.id = "%s_hidden_%d" % [card.id, Time.get_ticks_msec()]
	card.owner_id = "team"
	state.team_general_cards.append(card)
	_emit_log(tr("DEV_LOG_ADDED_SIX_SEVEN"))
	state_changed.emit(state)


## 根据 pending_card.effect_id 分发具体卡牌效果。
func _apply_card_effect(_answer_correct: bool, bonus_triggered: bool) -> void:
	# effect_id 决定行为；card_type 只负责 UI 分类和技能通用规则。
	var character: CharacterData = state.selected_character
	var card: CardData = state.pending_card
	if character == null or card == null:
		return

	match card.effect_id:
		"gain_team_ap":
			var gain: float = card.base_ap_gain + state.get_ap_growth_bonus()
			state.add_ap(gain)
			_emit_log(tr("LOG_TEAM_GAIN_AP") % gain)
		"attack_single":
			_apply_attack_card(character, card, bonus_triggered)
			_gain_question_card_ap(card, bonus_triggered)
		"attack_single_apply_effect":
			_apply_status_effect_attack(character, card, bonus_triggered)
			_gain_question_card_ap(card, bonus_triggered)
		"attack_primary_splash":
			_apply_primary_splash_attack(character, card, bonus_triggered)
			_gain_question_card_ap(card, bonus_triggered)
		"damage_current_hp_percent":
			_apply_current_hp_percent_damage(character, card)
		"apply_status_ally":
			_apply_status_to_ally(character, card)
		"apply_status_enemy":
			_apply_status_to_enemy(character, card)
		"heal_max_hp_percent":
			_apply_max_hp_percent_heal(character, card)
		"gall_of_goujian":
			_apply_gall_of_goujian(character, card)
		"apply_dual_status_ally":
			_apply_dual_status_to_ally(character, card)
		"direct_hp_loss":
			_apply_direct_hp_loss(character, card)
		"defend_single":
			var defense_target: CharacterData = state.selected_ally if state.selected_ally != null else character
			var block: float = card.base_block
			if bonus_triggered:
				block += card.get_block_bonus_for_difficulty(state.pending_difficulty)
			defense_target.add_turn_damage_reduction(block)
			_emit_log(tr("LOG_DEFENSE_GRANTED") % [tr(character.display_name), tr(defense_target.display_name), block * 100.0])
			_gain_question_card_ap(card, bonus_triggered)
		"skill_attack_single", "skill_attack_all":
			_apply_skill_card(character, card, bonus_triggered)
		_:
			push_error("BattleManager: unknown card effect_id '%s' for card '%s'." % [card.effect_id, card.id])

	if card.is_skill():
		state.clear_ap()
		_emit_log(tr("LOG_AP_CLEARED"))


## 结算单体攻击卡造成的伤害。
func _apply_attack_card(character: CharacterData, card: CardData, bonus_triggered: bool) -> void:
	var enemy: EnemyData = state.selected_enemy
	if enemy == null:
		return
	var damage: int = _calculate_damage(character, enemy, card.base_damage, card.get_damage_bonus_for_difficulty(state.pending_difficulty) if bonus_triggered else 0.0)
	var dealt: int = enemy.take_damage(damage)
	_emit_log(tr("LOG_ATTACK_DAMAGE") % [tr(character.display_name), tr(enemy.display_name), dealt])
	_collect_reward_if_dead(enemy)


## 先施加卡牌状态效果，再结算本次单体攻击。
func _apply_status_effect_attack(character: CharacterData, card: CardData, bonus_triggered: bool) -> void:
	# 先挂持续性效果，再调用普通攻击结算，确保本次伤害立即受到易伤影响。
	var enemy: EnemyData = state.selected_enemy
	if enemy == null:
		return
	var effect: StatusEffectData = EffectDatabase.create_effect(
		card.status_effect_id,
		card.status_effect_value,
		card.status_effect_duration,
		"%s::%s" % [character.id, card.id],
		card.display_name
	)
	if effect != null:
		enemy.apply_status_effect(effect)
		_emit_log(tr("LOG_EFFECT_APPLIED") % [
			tr(character.display_name),
			tr(enemy.display_name),
			tr(effect.display_name),
			effect.remaining_turns
		])
	_apply_attack_card(character, card, bonus_triggered)


## 结算选中目标全额、其他敌人半额的溅射攻击。
func _apply_primary_splash_attack(character: CharacterData, card: CardData, bonus_triggered: bool) -> void:
	# 选中目标使用完整基础伤害，其余存活敌人使用一半基础伤害并独立计算属性与答题加成。
	var primary_target: EnemyData = state.selected_enemy
	if primary_target == null:
		return
	var card_bonus: float = card.get_damage_bonus_for_difficulty(state.pending_difficulty) if bonus_triggered else 0.0
	for enemy: EnemyData in state.enemy_team:
		if not enemy.is_alive():
			continue
		var base_damage: int = card.base_damage if enemy == primary_target else roundi(float(card.base_damage) * 0.5)
		var damage: int = _calculate_damage(character, enemy, base_damage, card_bonus)
		var dealt: int = enemy.take_damage(damage)
		_emit_log(tr("LOG_ATTACK_DAMAGE") % [tr(character.display_name), tr(enemy.display_name), dealt])
		_collect_reward_if_dead(enemy)


## 按目标当前生命比例计算动态基础伤害并结算。
func _apply_current_hp_percent_damage(character: CharacterData, card: CardData) -> void:
	# 先按目标当前生命计算动态基础伤害，再进入统一增益、易伤、减伤和护盾结算。
	var enemy: EnemyData = state.selected_enemy
	if enemy == null:
		return
	var target_hp_before: int = enemy.current_hp
	var dynamic_base_damage: int = maxi(1, roundi(float(target_hp_before) * card.current_hp_damage_ratio))
	var damage: int = _calculate_damage(character, enemy, dynamic_base_damage, 0.0)
	var dealt: int = enemy.take_damage(damage)
	_emit_log(tr("LOG_CURRENT_HP_DAMAGE") % [
		tr(card.display_name),
		tr(enemy.display_name),
		target_hp_before,
		card.current_hp_damage_ratio * 100.0,
		dynamic_base_damage,
		dealt
	])
	_collect_reward_if_dead(enemy)


## 向选中的我方角色施加卡牌状态效果。
func _apply_status_to_ally(character: CharacterData, card: CardData) -> void:
	var target: CharacterData = state.selected_ally if state.selected_ally != null else character
	var effect: StatusEffectData = _create_card_status_effect(character, card)
	if target == null or effect == null:
		return
	target.apply_status_effect(effect)
	_emit_log(tr("LOG_ALLY_EFFECT_APPLIED") % [tr(card.display_name), tr(target.display_name), tr(effect.display_name)])


## 向选中的敌人施加卡牌状态效果。
func _apply_status_to_enemy(character: CharacterData, card: CardData) -> void:
	var target: EnemyData = state.selected_enemy
	var effect: StatusEffectData = _create_card_status_effect(character, card)
	if target == null or effect == null:
		return
	if target.apply_status_effect(effect):
		_emit_log(tr("LOG_ENEMY_EFFECT_APPLIED") % [tr(card.display_name), tr(target.display_name), tr(effect.display_name)])
	else:
		_emit_log(tr("LOG_EFFECT_SWALLOWED") % [tr(card.display_name), tr(target.display_name)])


## 按目标最大生命比例进行治疗。
func _apply_max_hp_percent_heal(character: CharacterData, card: CardData) -> void:
	var target: CharacterData = state.selected_ally if state.selected_ally != null else character
	if target == null:
		return
	var requested_heal: int = roundi(float(target.max_hp) * card.max_hp_heal_ratio)
	var healed: int = target.heal(requested_heal)
	_emit_log(tr("LOG_MAX_HP_HEAL") % [tr(card.display_name), tr(target.display_name), healed])


## 结算卧薪尝胆的先虚弱、后力量状态组合。
func _apply_gall_of_goujian(character: CharacterData, card: CardData) -> void:
	var target: CharacterData = state.selected_ally if state.selected_ally != null else character
	if target == null:
		return
	var weakness: StatusEffectData = target.get_status_effect_from_card("weakness", card.id)
	if weakness != null and weakness.is_active():
		_emit_log(tr("LOG_GALL_NO_EFFECT") % tr(target.display_name))
		return
	var strength: StatusEffectData = target.get_status_effect_from_card("strength", card.id)
	if strength != null and strength.is_active():
		strength.remaining_turns = card.secondary_status_effect_duration
		_emit_log(tr("LOG_GALL_STRENGTH_REFRESHED") % tr(target.display_name))
		return

	var weakness_effect: StatusEffectData = _create_card_status_effect(character, card)
	var strength_effect: StatusEffectData = _create_secondary_card_status_effect(character, card)
	target.apply_status_effect(weakness_effect)
	target.apply_status_effect(strength_effect)
	_emit_log(tr("LOG_GALL_APPLIED") % tr(target.display_name))


## 向我方角色同时施加主副两个状态效果。
func _apply_dual_status_to_ally(character: CharacterData, card: CardData) -> void:
	var target: CharacterData = state.selected_ally if state.selected_ally != null else character
	if target == null:
		return
	var primary_effect: StatusEffectData = _create_card_status_effect(character, card)
	var secondary_effect: StatusEffectData = _create_secondary_card_status_effect(character, card)
	if primary_effect != null:
		target.apply_status_effect(primary_effect)
	if secondary_effect != null:
		target.apply_status_effect(secondary_effect)
	_emit_log(tr("LOG_DUAL_EFFECT_APPLIED") % [tr(card.display_name), tr(target.display_name)])


## 结算直接生命损失效果，不走普通伤害流程。
func _apply_direct_hp_loss(character: CharacterData, card: CardData) -> void:
	var target: CharacterData = state.selected_ally if state.selected_ally != null else character
	if target == null:
		return
	var lost_hp: int = target.lose_hp_direct(card.direct_hp_loss)
	_emit_log(tr("LOG_DIRECT_HP_LOSS") % [tr(card.display_name), tr(target.display_name), lost_hp])


## 根据卡牌主状态字段创建运行时状态实例。
func _create_card_status_effect(character: CharacterData, card: CardData) -> StatusEffectData:
	return EffectDatabase.create_effect(
		card.status_effect_id,
		card.status_effect_value,
		card.status_effect_duration,
		"%s::%s" % [character.id, card.id],
		card.display_name,
		card.status_effect_delay
	)


## 根据卡牌副状态字段创建运行时状态实例。
func _create_secondary_card_status_effect(character: CharacterData, card: CardData) -> StatusEffectData:
	if card.secondary_status_effect_id.is_empty():
		return null
	return EffectDatabase.create_effect(
		card.secondary_status_effect_id,
		card.secondary_status_effect_value,
		card.secondary_status_effect_duration,
		"%s::%s" % [character.id, card.id],
		card.display_name,
		card.secondary_status_effect_delay
	)


## 结算技能卡的单体或全体伤害。
func _apply_skill_card(character: CharacterData, card: CardData, bonus_triggered: bool) -> void:
	# 当前技能答对统一获得 25% 伤害倍率，范围由 target_type 决定。
	var extra_bonus: float = 0.25 if bonus_triggered else 0.0
	if card.target_type == CardData.TargetType.ALL_ENEMIES:
		for enemy: EnemyData in state.enemy_team:
			if enemy.is_alive():
				var damage: int = _calculate_damage(character, enemy, card.base_damage, extra_bonus)
				var dealt: int = enemy.take_damage(damage)
				_emit_log(tr("LOG_SKILL_HIT_ALL") % [tr(character.display_name), tr(enemy.display_name), dealt])
				_collect_reward_if_dead(enemy)
	else:
		var enemy: EnemyData = state.selected_enemy
		if enemy != null:
			var damage: int = _calculate_damage(character, enemy, card.base_damage, extra_bonus)
			var dealt: int = enemy.take_damage(damage)
			_emit_log(tr("LOG_SKILL_HIT_ONE") % [tr(character.display_name), tr(enemy.display_name), dealt])
			_collect_reward_if_dead(enemy)


## 计算我方卡牌伤害的最终入参伤害值。
func _calculate_damage(character: CharacterData, enemy: EnemyData, base_damage: int, card_bonus: float) -> int:
	# 我方没有角色攻击值：卡牌伤害叠加拼音、同属性和答题倍率。
	var multiplier: float = state.get_team_stat_multiplier()
	if character.attribute == enemy.attribute:
		multiplier += 0.20
	multiplier += card_bonus
	return maxi(1, roundi(float(base_damage) * multiplier * character.get_outgoing_damage_multiplier()))


## 为攻击/防御答题卡增加基础 AP 和可能的难度 AP。
func _gain_question_card_ap(card: CardData, bonus_triggered: bool) -> void:
	# 攻击/防御卡无论答案均获得基础 AP；答对或词汇补偿才获得难度额外 AP。
	var difficulty_bonus: float = card.get_correct_answer_ap_bonus(state.pending_difficulty) if bonus_triggered else 0.0
	var gain: float = card.base_ap_gain + difficulty_bonus + state.get_ap_growth_bonus()
	state.add_ap(gain)
	_emit_log(tr("LOG_TEAM_GAIN_AP") % gain)


## 标记本次行动完成，并决定继续玩家回合或进入敌方回合。
func _finish_player_action() -> void:
	# 通用卡使用后移除；所有存活角色行动完毕后自动进入敌方回合。
	if state.selected_character != null:
		state.selected_character.mark_acted()
		if state.pending_card != null and state.pending_card.is_general():
			var used_card_index: int = state.team_general_cards.find(state.pending_card)
			if used_card_index != -1:
				state.team_general_cards.remove_at(used_card_index)
	state.clear_pending_action()

	if _check_battle_end():
		state_changed.emit(state)
		return

	if state.did_all_living_players_act():
		_run_enemy_turn()
	else:
		state.phase = BattleState.Phase.PLAYER_TURN
		state_changed.emit(state)


## 按顺序执行全部存活敌人的回合。
func _run_enemy_turn() -> void:
	# 每个存活敌人依次行动；技能由各自 abilities 权重选择。
	state.phase = BattleState.Phase.ENEMY_TURN
	state_changed.emit(state)
	_emit_log(tr("LOG_ENEMY_TURN_START"))

	for enemy: EnemyData in state.enemy_team:
		if not enemy.is_alive():
			continue
		_run_enemy_action(enemy)
		if _check_battle_end():
			state_changed.emit(state)
			return

	state.start_player_turn()
	_emit_log(tr("LOG_NEXT_PLAYER_TURN") % state.turn_count)
	state_changed.emit(state)


## 为单个敌人选择并执行一个技能。
func _run_enemy_action(enemy: EnemyData) -> void:
	# 每回合按配置权重选择一个技能；新增技能 ID 时扩展此分发入口。
	if enemy.consume_all_status_effects("stun") > 0:
		_emit_log(tr("LOG_ENEMY_STUNNED") % tr(enemy.display_name))
		return
	var ability: EnemyAbilityData = enemy.choose_ability(rng)
	if ability == null:
		return
	match ability.id:
		"slime_team_shield":
			_run_slime_support(enemy, ability.power)
		"bun_group_attack":
			_run_bun_group_attack(enemy, ability.power)
		"mask_single_attack":
			_run_mask_single_attack(enemy, ability.power)
		_:
			push_error("BattleManager: unknown enemy ability '%s' for '%s'." % [ability.id, enemy.id])


## 执行史莱姆的全体敌方护盾辅助。
func _run_slime_support(enemy: EnemyData, power: int) -> void:
	# 史莱姆没有攻击能力，为所有存活敌人提供可叠加护盾。
	var shield_amount: int = maxi(0, power)
	for ally: EnemyData in state.enemy_team:
		if ally.is_alive():
			ally.add_shield(shield_amount)
	_emit_log(tr("LOG_ENEMY_SHIELD_ALL") % [tr(enemy.display_name), shield_amount])


## 执行包子的我方全体攻击。
func _run_bun_group_attack(enemy: EnemyData, power: int) -> void:
	# 包子对每名存活角色分别结算伤害及同属性减伤。
	for target: CharacterData in state.get_alive_players():
		var dealt: int = target.take_damage(maxi(0, power), enemy.attribute)
		if target.last_damage_was_immune:
			_emit_log(tr("LOG_DAMAGE_IMMUNED") % [tr(target.display_name), tr(enemy.display_name)])
		else:
			_emit_log(tr("LOG_ENEMY_GROUP_ATTACK") % [tr(enemy.display_name), tr(target.display_name), dealt])


## 执行面具的随机单体攻击。
func _run_mask_single_attack(enemy: EnemyData, power: int) -> void:
	# 面具随机选择一名存活角色进行基础单体攻击。
	var target: CharacterData = _get_random_alive_player()
	if target == null:
		return
	var dealt: int = target.take_damage(maxi(0, power), enemy.attribute)
	if target.last_damage_was_immune:
		_emit_log(tr("LOG_DAMAGE_IMMUNED") % [tr(target.display_name), tr(enemy.display_name)])
	else:
		_emit_log(tr("LOG_ENEMY_ATTACK") % [tr(enemy.display_name), tr(target.display_name), dealt])


## 检查胜负或波次推进，并在需要时发出结果信号。
func _check_battle_end() -> bool:
	if state.are_all_enemies_dead():
		if state.current_wave < state.total_waves:
			_start_next_wave()
			return true
		state.phase = BattleState.Phase.VICTORY
		result_requested.emit(tr("RESULT_VICTORY_TITLE"), tr("RESULT_VICTORY_MESSAGE") % state.new_toefl, true, true)
		return true
	if state.are_all_players_dead():
		state.phase = BattleState.Phase.DEFEAT
		result_requested.emit(tr("RESULT_DEFEAT_TITLE"), tr("RESULT_DEFEAT_MESSAGE"), true, false)
		return true
	return false


## 清场后生成下一波敌人并开始新的玩家回合。
func _start_next_wave() -> void:
	# 清场后立即生成下一波并开启新的我方回合，敌方不会抢先行动。
	var next_wave_index: int = state.current_wave
	var next_enemies: Array[EnemyData] = GameDataFactory.create_level_wave(active_level, next_wave_index, rng)
	state.replace_enemy_wave(next_enemies, state.current_wave + 1)
	state.start_player_turn()
	_emit_log(tr("LOG_WAVE_START") % [state.current_wave, state.total_waves])
	_emit_log(tr("LOG_NEXT_PLAYER_TURN") % state.turn_count)


## 在敌人首次死亡时结算 TOEFL 和随机通用卡奖励。
func _collect_reward_if_dead(enemy: EnemyData) -> void:
	# 独立标记确保每名敌人的货币与通用卡掉落都只结算一次。
	if enemy.is_alive() or enemy.rewards_collected:
		return
	enemy.rewards_collected = true

	if enemy.toefl_reward > 0.0:
		state.add_new_toefl(enemy.toefl_reward)
		_emit_log(tr("LOG_ENEMY_REWARD") % [tr(enemy.display_name), enemy.toefl_reward])

	var dropped_card: CardData = GameDataFactory.create_enemy_drop_general_card(rng)
	if dropped_card != null:
		dropped_card.owner_id = "team"
		state.team_general_cards.append(dropped_card)
		_emit_log(tr("LOG_ENEMY_CARD_DROP") % [tr(enemy.display_name), tr(dropped_card.display_name)])


## 按索引获取敌人目标，索引无效时回退到第一名存活敌人。
func _get_enemy_or_first_alive(index: int) -> EnemyData:
	if index >= 0 and index < state.enemy_team.size() and state.enemy_team[index].is_alive():
		return state.enemy_team[index]
	for enemy: EnemyData in state.enemy_team:
		if enemy.is_alive():
			return enemy
	return null


## 按索引获取我方目标，索引无效时回退到行动者。
func _get_ally_or_actor(index: int, actor: CharacterData) -> CharacterData:
	if index >= 0 and index < state.player_team.size() and state.player_team[index].is_alive():
		return state.player_team[index]
	return actor if actor != null and actor.is_alive() else null


## 从当前存活我方角色中随机选择一个。
func _get_random_alive_player() -> CharacterData:
	var alive := state.get_alive_players()
	if alive.is_empty():
		return null
	return alive[rng.randi_range(0, alive.size() - 1)]


## 判断卡牌请求是否必须带有敌方目标。
func _card_needs_enemy(card: CardData) -> bool:
	return card.targets_single_enemy()


## 判断卡牌请求是否必须带有我方目标。
func _card_needs_ally(card: CardData) -> bool:
	return card.targets_ally()


## 写入战斗日志并通知 UI 增量刷新。
func _emit_log(message: String) -> void:
	state.push_log(message)
	log_added.emit(message)


## 从通用卡池随机生成商店本轮货架。
func _roll_shop_offers() -> void:
	state.shop_offer_cards = GameDataFactory.create_shop_general_offers(rng, 4)


## 根据 UI 索引取出角色专属卡或队伍通用卡。
func _get_card_for_request(character: CharacterData, card_index: int) -> CardData:
	# 负数编码区分队伍通用卡与角色 cards 数组，保持现有 UI 信号格式。
	if _is_team_general_card_index(card_index):
		var team_card_index: int = _decode_team_general_card_index(card_index)
		if team_card_index >= 0 and team_card_index < state.team_general_cards.size():
			return state.team_general_cards[team_card_index]
		return null
	if card_index >= 0 and card_index < character.cards.size():
		return character.cards[card_index]
	return null


## 判断 UI 索引是否指向队伍通用牌。
func _is_team_general_card_index(card_index: int) -> bool:
	return card_index <= -TEAM_GENERAL_CARD_INDEX_OFFSET


## 将队伍通用牌 UI 负数索引还原成数组索引。
func _decode_team_general_card_index(card_index: int) -> int:
	return -card_index - TEAM_GENERAL_CARD_INDEX_OFFSET


## 将难度 id 转为本地化显示文本。
func _difficulty_label(difficulty: String) -> String:
	match difficulty:
		"easy":
			return tr("DIFFICULTY_EASY")
		"medium":
			return tr("DIFFICULTY_MEDIUM")
		"hard":
			return tr("DIFFICULTY_HARD")
		_:
			return difficulty
