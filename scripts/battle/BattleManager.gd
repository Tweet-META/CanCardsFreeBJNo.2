extends Node
## 战斗规则与回合状态机；通过 signal 通知 UI，不直接操作界面节点。
class_name BattleManager

signal state_changed(state: BattleState)
signal question_requested(question: QuestionData)
signal result_requested(title: String, message: String, battle_over: bool, victory: bool)
signal log_added(message: String)

var state: BattleState = BattleState.new()
var question_bank: QuestionBank = QuestionBank.new()
var rng: RandomNumberGenerator = RandomNumberGenerator.new()

const TEAM_GENERAL_CARD_INDEX_OFFSET: int = 1000


func _ready() -> void:
	rng.randomize()
	start_new_battle()


func start_new_battle() -> void:
	# 每局都从数据库创建全新角色、敌人和卡牌实例。
	state.setup(GameDataFactory.create_player_team(), GameDataFactory.create_enemy_team(), rng)
	_roll_shop_offers()
	state.push_log(tr("LOG_BATTLE_START"))
	state.start_player_turn()
	_emit_log(tr("LOG_PLAYER_TURN_START") % state.turn_count)
	state_changed.emit(state)


func request_use_card(character_index: int, card_index: int, enemy_index: int, ally_index: int, difficulty: String) -> void:
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
	# 技能自动固定困难，其余卡牌沿用玩家选择的难度。
	state.pending_difficulty = card.get_question_difficulty(difficulty)

	if not card.requires_question:
		_apply_card_effect(false, true)
		_finish_player_action()
		return

	state.phase = BattleState.Phase.QUESTION
	state.pending_question = question_bank.get_random_question(card.required_attribute, state.pending_difficulty, rng)
	_emit_log(tr("LOG_CARD_QUESTION") % [tr(character.display_name), tr(card.display_name), _difficulty_label(state.pending_difficulty)])
	question_requested.emit(state.pending_question)
	state_changed.emit(state)


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


func retry_battle() -> void:
	start_new_battle()


func request_refresh_shop() -> void:
	if not state.spend_new_toefl(0.5):
		_emit_log(tr("LOG_REFRESH_NO_FUNDS"))
		state_changed.emit(state)
		return
	_roll_shop_offers()
	_emit_log(tr("LOG_SHOP_REFRESHED"))
	state_changed.emit(state)


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


func developer_add_general_card() -> void:
	if not SettingsManager.developer_mode:
		return
	var card: CardData = GameDataFactory.create_general_encouragement_i()
	card.id = "%s_dev_%d" % [card.id, Time.get_ticks_msec()]
	card.owner_id = "team"
	state.team_general_cards.append(card)
	_emit_log(tr("DEV_LOG_ADDED_CARD"))
	state_changed.emit(state)


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
			if bonus_triggered:
				_gain_answer_ap(character, card)
		"defend_single":
			var defense_target: CharacterData = state.selected_ally if state.selected_ally != null else character
			var block: float = card.base_block
			if bonus_triggered:
				block += card.get_block_bonus_for_difficulty(state.pending_difficulty)
			defense_target.add_turn_damage_reduction(block)
			_emit_log(tr("LOG_DEFENSE_GRANTED") % [tr(character.display_name), tr(defense_target.display_name), block * 100.0])
			if bonus_triggered:
				_gain_answer_ap(character, card)
		"skill_attack_single", "skill_attack_all":
			_apply_skill_card(character, card, bonus_triggered)
		_:
			push_error("BattleManager: unknown card effect_id '%s' for card '%s'." % [card.effect_id, card.id])

	if card.is_skill():
		state.clear_ap()
		_emit_log(tr("LOG_AP_CLEARED"))


func _apply_attack_card(character: CharacterData, card: CardData, bonus_triggered: bool) -> void:
	var enemy: EnemyData = state.selected_enemy
	if enemy == null:
		return
	var damage: int = _calculate_damage(character, enemy, card.base_damage, card.get_damage_bonus_for_difficulty(state.pending_difficulty) if bonus_triggered else 0.0)
	var dealt: int = enemy.take_damage(damage)
	_emit_log(tr("LOG_ATTACK_DAMAGE") % [tr(character.display_name), tr(enemy.display_name), dealt])
	_collect_reward_if_dead(enemy)


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


func _calculate_damage(character: CharacterData, enemy: EnemyData, base_damage: int, card_bonus: float) -> int:
	# 我方没有角色攻击值：卡牌伤害叠加拼音、同属性和答题倍率。
	var multiplier: float = state.get_team_stat_multiplier()
	if character.attribute == enemy.attribute:
		multiplier += 0.20
	multiplier += card_bonus
	return maxi(1, roundi(float(base_damage) * multiplier))


func _gain_answer_ap(character: CharacterData, card: CardData) -> void:
	var gain: float = card.base_ap_gain + card.get_correct_answer_ap_bonus(state.pending_difficulty) + state.get_ap_growth_bonus()
	state.add_ap(gain)
	_emit_log(tr("LOG_TEAM_GAIN_AP") % gain)


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


func _run_enemy_turn() -> void:
	# 每个存活敌人按原型行动；属性仍参与我方同属性减伤判定。
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


func _run_enemy_action(enemy: EnemyData) -> void:
	# 原型行为集中在这里，新增属性变体时只需配置 JSON，无需复制战斗代码。
	match enemy.prototype:
		EnemyData.PROTOTYPE_SLIME:
			_run_slime_support(enemy)
		EnemyData.PROTOTYPE_BUN:
			_run_bun_group_attack(enemy)
		EnemyData.PROTOTYPE_MASK:
			_run_mask_single_attack(enemy)
		_:
			_run_mask_single_attack(enemy)


func _run_slime_support(enemy: EnemyData) -> void:
	# 史莱姆没有攻击能力，为所有存活敌人提供可叠加护盾。
	var shield_amount: int = enemy.get_ability_power()
	for ally: EnemyData in state.enemy_team:
		if ally.is_alive():
			ally.add_shield(shield_amount)
	_emit_log(tr("LOG_ENEMY_SHIELD_ALL") % [tr(enemy.display_name), shield_amount])


func _run_bun_group_attack(enemy: EnemyData) -> void:
	# 包子对每名存活角色分别结算伤害及同属性减伤。
	for target: CharacterData in state.get_alive_players():
		var dealt: int = target.take_damage(enemy.get_basic_attack_damage(), enemy.attribute)
		_emit_log(tr("LOG_ENEMY_GROUP_ATTACK") % [tr(enemy.display_name), tr(target.display_name), dealt])


func _run_mask_single_attack(enemy: EnemyData) -> void:
	# 面具随机选择一名存活角色进行基础单体攻击。
	var target: CharacterData = _get_random_alive_player()
	if target == null:
		return
	var dealt: int = target.take_damage(enemy.get_basic_attack_damage(), enemy.attribute)
	_emit_log(tr("LOG_ENEMY_ATTACK") % [tr(enemy.display_name), tr(target.display_name), dealt])


func _check_battle_end() -> bool:
	if state.are_all_enemies_dead():
		state.phase = BattleState.Phase.VICTORY
		result_requested.emit(tr("RESULT_VICTORY_TITLE"), tr("RESULT_VICTORY_MESSAGE") % state.new_toefl, true, true)
		return true
	if state.are_all_players_dead():
		state.phase = BattleState.Phase.DEFEAT
		result_requested.emit(tr("RESULT_DEFEAT_TITLE"), tr("RESULT_DEFEAT_MESSAGE"), true, false)
		return true
	return false


func _collect_reward_if_dead(enemy: EnemyData) -> void:
	# 奖励清零可确保同一敌人只结算一次 TOEFL。
	if not enemy.is_alive() and enemy.toefl_reward > 0.0:
		state.add_new_toefl(enemy.toefl_reward)
		_emit_log(tr("LOG_ENEMY_REWARD") % [tr(enemy.display_name), enemy.toefl_reward])
		enemy.toefl_reward = 0.0


func _get_enemy_or_first_alive(index: int) -> EnemyData:
	if index >= 0 and index < state.enemy_team.size() and state.enemy_team[index].is_alive():
		return state.enemy_team[index]
	for enemy: EnemyData in state.enemy_team:
		if enemy.is_alive():
			return enemy
	return null


func _get_ally_or_actor(index: int, actor: CharacterData) -> CharacterData:
	if index >= 0 and index < state.player_team.size() and state.player_team[index].is_alive():
		return state.player_team[index]
	return actor if actor != null and actor.is_alive() else null


func _get_random_alive_player() -> CharacterData:
	var alive := state.get_alive_players()
	if alive.is_empty():
		return null
	return alive[rng.randi_range(0, alive.size() - 1)]


func _card_needs_enemy(card: CardData) -> bool:
	return card.target_type == CardData.TargetType.SINGLE_ENEMY


func _card_needs_ally(card: CardData) -> bool:
	return card.card_type == CardData.CardType.DEFENSE


func _emit_log(message: String) -> void:
	state.push_log(message)
	log_added.emit(message)


func _roll_shop_offers() -> void:
	state.shop_offer_cards = GameDataFactory.create_shop_general_offers(rng, 4)


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


func _is_team_general_card_index(card_index: int) -> bool:
	return card_index <= -TEAM_GENERAL_CARD_INDEX_OFFSET


func _decode_team_general_card_index(card_index: int) -> int:
	return -card_index - TEAM_GENERAL_CARD_INDEX_OFFSET


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
