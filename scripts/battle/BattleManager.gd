extends Node
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
	state.setup(GameDataFactory.create_player_team(), GameDataFactory.create_enemy_team())
	_roll_shop_offers()
	state.push_log("战斗开始：三位吉祥物准备好了。")
	state.start_player_turn()
	_emit_log("玩家回合 %d：请选择角色和卡牌。" % state.turn_count)
	state_changed.emit(state)


func request_use_card(character_index: int, card_index: int, enemy_index: int, ally_index: int, difficulty: String) -> void:
	if state.phase != BattleState.Phase.PLAYER_TURN:
		_emit_log("现在不能使用卡牌。")
		return
	if character_index < 0 or character_index >= state.player_team.size():
		return

	var character: CharacterData = state.player_team[character_index]
	if not character.is_alive():
		_emit_log("%s 已无法行动。" % character.display_name)
		return
	if character.has_acted:
		_emit_log("%s 本回合已经行动过。" % character.display_name)
		return
	var card: CardData = _get_card_for_request(character, card_index)
	if card == null:
		return

	if not card.can_use(state.ap):
		_emit_log("%s 需要 AP ≥ %.1f。" % [card.display_name, card.skill_ap_cost])
		return

	var target_enemy: EnemyData = _get_enemy_or_first_alive(enemy_index)
	if _card_needs_enemy(card) and target_enemy == null:
		_emit_log("没有可攻击的敌人。")
		return
	var target_ally: CharacterData = _get_ally_or_actor(ally_index, character)
	if _card_needs_ally(card) and target_ally == null:
		_emit_log("请选择一名我方角色作为防御目标。")
		return

	state.selected_character = character
	state.selected_ally = target_ally
	state.selected_enemy = target_enemy
	state.pending_card = card
	state.pending_difficulty = card.get_question_difficulty(difficulty)

	if not card.requires_question:
		_apply_card_effect(false, true)
		_finish_player_action()
		return

	state.phase = BattleState.Phase.QUESTION
	state.pending_question = question_bank.get_random_question(card.required_attribute, state.pending_difficulty, rng)
	_emit_log("%s 使用 %s，需要回答%s题。" % [character.display_name, card.display_name, _difficulty_label(state.pending_difficulty)])
	question_requested.emit(state.pending_question)
	state_changed.emit(state)


func submit_answer(answer_index: int) -> void:
	if state.phase != BattleState.Phase.QUESTION or state.pending_question == null:
		return

	var correct: bool = state.pending_question.is_answer_correct(answer_index)
	var bonus_triggered: bool = correct
	if not correct:
		var chance: float = state.get_wrong_answer_bonus_chance()
		bonus_triggered = rng.randf() < chance

	var answer_text: String = "回答正确" if correct else "回答错误"
	if bonus_triggered and not correct:
		answer_text += "，词汇被动触发，加成仍然生效"

	_apply_card_effect(correct, bonus_triggered)
	_emit_log(answer_text + "。")
	result_requested.emit(answer_text, state.pending_question.explanation, false, false)
	_finish_player_action()


func end_player_turn() -> void:
	if state.phase != BattleState.Phase.PLAYER_TURN:
		return
	_run_enemy_turn()


func retry_battle() -> void:
	start_new_battle()


func request_refresh_shop() -> void:
	if not state.spend_new_toefl(0.5):
		_emit_log("New TOEFL 不足，无法刷新商店。")
		state_changed.emit(state)
		return
	_roll_shop_offers()
	_emit_log("花费 0.5 New TOEFL 刷新商店。")
	state_changed.emit(state)


func request_buy_shop_card(offer_index: int, character_index: int) -> void:
	if offer_index < 0 or offer_index >= state.shop_offer_cards.size():
		return
	if character_index < 0 or character_index >= state.player_team.size():
		return
	var target_character: CharacterData = state.player_team[character_index]
	if not target_character.is_alive():
		_emit_log("无法给无法行动的角色购买卡牌。")
		state_changed.emit(state)
		return

	var offer_card: CardData = state.shop_offer_cards[offer_index]
	if not state.spend_new_toefl(offer_card.shop_price):
		_emit_log("New TOEFL 不足，无法购买 %s。" % offer_card.display_name)
		state_changed.emit(state)
		return

	var bought_card: CardData = offer_card.duplicate(true) as CardData
	bought_card.id = "%s_bought_%d" % [offer_card.id, Time.get_ticks_msec()]
	bought_card.owner_id = "team"
	state.team_general_cards.append(bought_card)
	_emit_log("队伍购买了 %s，花费 %.1f New TOEFL。" % [bought_card.display_name, offer_card.shop_price])
	state_changed.emit(state)


func _apply_card_effect(answer_correct: bool, bonus_triggered: bool) -> void:
	var character: CharacterData = state.selected_character
	var card: CardData = state.pending_card
	if character == null or card == null:
		return

	match card.card_type:
		CardData.CardType.GENERAL:
			var gain: float = card.base_ap_gain + state.get_ap_growth_bonus()
			state.add_ap(gain)
			_emit_log("队伍获得 %.2f AP。" % gain)
		CardData.CardType.ATTACK:
			_apply_attack_card(character, card, bonus_triggered)
			if bonus_triggered:
				_gain_answer_ap(character, card)
		CardData.CardType.DEFENSE:
			var defense_target: CharacterData = state.selected_ally if state.selected_ally != null else character
			var block: float = card.base_block
			if bonus_triggered:
				block += card.get_block_bonus_for_difficulty(state.pending_difficulty)
			defense_target.add_turn_damage_reduction(block)
			_emit_log("%s 为 %s 提供 %.0f%% 本回合减伤。" % [character.display_name, defense_target.display_name, block * 100.0])
			if bonus_triggered:
				_gain_answer_ap(character, card)
		CardData.CardType.SKILL:
			_apply_skill_card(character, card, bonus_triggered)
			state.clear_ap()
			_emit_log("队伍 AP 清零。")


func _apply_attack_card(character: CharacterData, card: CardData, bonus_triggered: bool) -> void:
	var enemy: EnemyData = state.selected_enemy
	if enemy == null:
		return
	var damage: int = _calculate_damage(character, enemy, card.base_damage, card.get_damage_bonus_for_difficulty(state.pending_difficulty) if bonus_triggered else 0.0)
	var dealt: int = enemy.take_damage(damage)
	_emit_log("%s 对 %s 造成 %d 伤害。" % [character.display_name, enemy.display_name, dealt])
	_collect_reward_if_dead(enemy)


func _apply_skill_card(character: CharacterData, card: CardData, bonus_triggered: bool) -> void:
	var extra_bonus: float = 0.25 if bonus_triggered else 0.0
	if card.target_type == CardData.TargetType.ALL_ENEMIES:
		for enemy: EnemyData in state.enemy_team:
			if enemy.is_alive():
				var damage: int = _calculate_damage(character, enemy, card.base_damage, extra_bonus)
				var dealt: int = enemy.take_damage(damage)
				_emit_log("%s 的技能击中 %s，造成 %d 伤害。" % [character.display_name, enemy.display_name, dealt])
				_collect_reward_if_dead(enemy)
	else:
		var enemy: EnemyData = state.selected_enemy
		if enemy != null:
			var damage: int = _calculate_damage(character, enemy, card.base_damage, extra_bonus)
			var dealt: int = enemy.take_damage(damage)
			_emit_log("%s 的技能对 %s 造成 %d 伤害。" % [character.display_name, enemy.display_name, dealt])
			_collect_reward_if_dead(enemy)


func _calculate_damage(character: CharacterData, enemy: EnemyData, base_damage: int, card_bonus: float) -> int:
	var multiplier: float = state.get_team_stat_multiplier()
	if character.attribute == enemy.attribute:
		multiplier += 0.20
	multiplier += card_bonus
	return maxi(1, roundi(float(base_damage + character.attack) * multiplier))


func _gain_answer_ap(character: CharacterData, card: CardData) -> void:
	var gain: float = card.base_ap_gain + card.get_correct_answer_ap_bonus(state.pending_difficulty) + state.get_ap_growth_bonus()
	state.add_ap(gain)
	_emit_log("队伍获得 %.2f AP。" % gain)


func _finish_player_action() -> void:
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
	state.phase = BattleState.Phase.ENEMY_TURN
	state_changed.emit(state)
	_emit_log("敌方回合开始。")

	for enemy: EnemyData in state.enemy_team:
		if not enemy.is_alive():
			continue
		var target: CharacterData = _get_random_alive_player()
		if target == null:
			break
		var raw_damage: int = enemy.get_basic_attack_damage()
		var dealt: int = target.take_damage(raw_damage, enemy.attribute)
		_emit_log("%s 攻击 %s，造成 %d 伤害。" % [enemy.display_name, target.display_name, dealt])
		if _check_battle_end():
			state_changed.emit(state)
			return

	state.start_player_turn()
	_emit_log("玩家回合 %d：请选择尚未行动的角色。" % state.turn_count)
	state_changed.emit(state)


func _check_battle_end() -> bool:
	if state.are_all_enemies_dead():
		state.phase = BattleState.Phase.VICTORY
		result_requested.emit("胜利", "敌方全灭！本关 MVP 完成。New TOEFL：%.1f" % state.new_toefl, true, true)
		return true
	if state.are_all_players_dead():
		state.phase = BattleState.Phase.DEFEAT
		result_requested.emit("失败", "我方全灭。失败无惩罚，可以重新挑战。", true, false)
		return true
	return false


func _collect_reward_if_dead(enemy: EnemyData) -> void:
	if not enemy.is_alive() and enemy.toefl_reward > 0.0:
		state.add_new_toefl(enemy.toefl_reward)
		_emit_log("击败 %s，获得 %.1f New TOEFL。" % [enemy.display_name, enemy.toefl_reward])
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
			return "简单"
		"medium":
			return "中等"
		"hard":
			return "困难"
		_:
			return difficulty
