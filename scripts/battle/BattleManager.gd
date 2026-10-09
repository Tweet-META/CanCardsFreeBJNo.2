extends Node
## Defines the BattleManager script.
class_name BattleManager

signal state_changed(state: BattleState)
signal difficulty_requested()
signal question_requested(question: QuestionData)
signal result_requested(title: String, message: String, battle_over: bool, victory: bool)
signal log_added(message: String)
signal presentation_requested(request_id: int, kind: StringName, actor_index: int, targets: Array[int])
signal presentation_finished(request_id: int)

var state: BattleState = BattleState.new()
var question_bank: QuestionBank = QuestionBank.new()
var rng: RandomNumberGenerator = RandomNumberGenerator.new()
var active_level: LevelData
var _battle_generation: int = 0
var _next_presentation_id: int = 0
var _waiting_presentation_id: int = -1
var _hit_player_indices: Array[int] = []

const TEAM_GENERAL_CARD_INDEX_OFFSET: int = 1000


## Ready.
func _ready() -> void:
	rng.randomize()
	start_new_battle()


## Start new battle.
func start_new_battle() -> void:
	_start_battle_with_level(LevelDatabase.get_active_level())


## Start battle with level.
func _start_battle_with_level(level: LevelData) -> void:
	_cancel_presentation()
	active_level = level
	if active_level == null or active_level.waves.is_empty():
		push_error("BattleManager: active level has no waves.")
		return
	var first_wave: Array[EnemyData] = GameDataFactory.create_level_wave(active_level, 0, rng)
	state.setup(
		GameDataFactory.create_player_team(),
		first_wave,
		active_level,
		GameDataFactory.create_active_learning_goal(),
		rng
	)
	_roll_shop_offers()
	state.push_log(tr("LOG_BATTLE_START"))
	_emit_log(tr("LOG_WAVE_START") % [state.current_wave, state.total_waves])
	_start_player_turn()
	_emit_log(tr("LOG_PLAYER_TURN_START") % state.turn_count)
	_emit_tutorial_tip("attack")
	state_changed.emit(state)


## Validates actions and reports concise feedback without naming the chosen card.
func request_use_card(character_index: int, card_index: int, enemy_index: int, ally_index: int) -> void:
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
	if card.is_general() and not state.general_cards_enabled:
		return

	if not card.can_use(state.ap):
		_emit_log(tr("LOG_CARD_AP_REQUIRED") % card.skill_ap_cost)
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
		_resolve_player_action(false, true)
		return

	if card.is_skill():
		_begin_question("hard")
		return
	if card.card_type == CardData.CardType.ATTACK or card.card_type == CardData.CardType.DEFENSE:
		state.phase = BattleState.Phase.DIFFICULTY_SELECTION
		_emit_tutorial_tip("defense" if card.card_type == CardData.CardType.DEFENSE else "difficulty")
		difficulty_requested.emit()
		state_changed.emit(state)
		return

	_begin_question("easy")


## Select question difficulty.
func select_question_difficulty(difficulty: String) -> void:
	if state.phase != BattleState.Phase.DIFFICULTY_SELECTION:
		return
	if difficulty not in ["easy", "medium", "hard"]:
		return
	_begin_question(difficulty)


## Opens the question panel without adding card or question narration to the log.
func _begin_question(difficulty: String) -> void:
	var character: CharacterData = state.selected_character
	var card: CardData = state.pending_card
	if character == null or card == null:
		return
	state.pending_difficulty = card.get_question_difficulty(difficulty)
	state.phase = BattleState.Phase.QUESTION
	state.pending_question = question_bank.get_random_question_by_difficulty(state.pending_difficulty, rng)
	_emit_tutorial_tip("question")
	question_requested.emit(state.pending_question)
	state_changed.emit(state)


## Keeps answer feedback in the result panel and logs effects only after resolution.
func submit_answer(answer_index: int) -> void:
	if state.phase != BattleState.Phase.QUESTION or state.pending_question == null:
		return

	var correct: bool = state.pending_question.is_answer_correct(answer_index)
	var bonus_triggered: bool = correct
	if not correct:
		var chance: float = state.get_wrong_answer_bonus_chance()
		bonus_triggered = rng.randf() < chance

	var answer_text: String = tr("RESULT_CORRECT") if correct else tr("RESULT_WRONG")
	if bonus_triggered and not correct:
		answer_text += tr("RESULT_VOCABULARY_GOAL_TRIGGER")

	state.pending_answer_correct = correct
	state.pending_answer_bonus_triggered = bonus_triggered
	state.phase = BattleState.Phase.ANSWER_RESULT
	_emit_tutorial_tip("result")
	result_requested.emit(answer_text, tr(state.pending_question.explanation), false, false)
	state_changed.emit(state)


## Resolves the retained answer only after its explanation panel has been dismissed.
func continue_after_answer() -> void:
	if state.phase != BattleState.Phase.ANSWER_RESULT:
		return
	_resolve_player_action(state.pending_answer_correct, state.pending_answer_bonus_triggered)


## Locks the turn, plays damaging-card animations, and then applies the existing rules.
func _resolve_player_action(correct: bool, bonus_triggered: bool) -> void:
	var character: CharacterData = state.selected_character
	var card: CardData = state.pending_card
	if character == null or card == null:
		return
	state.phase = BattleState.Phase.ACTION_RESOLUTION
	state_changed.emit(state)
	if card.base_damage > 0 or card.effect_id == "damage_current_hp_percent":
		var actor_index: int = state.player_team.find(character)
		if not await _present(&"player_attack", actor_index):
			return
	_hit_player_indices.clear()
	_apply_card_effect(correct, bonus_triggered)
	if not _hit_player_indices.is_empty():
		state_changed.emit(state)
		if not await _present(&"player_hurt", -1, _hit_player_indices.duplicate()):
			return
	await _finish_player_action()


## Releases only the current visual request; stale callbacks cannot advance a later battle.
func complete_presentation(request_id: int) -> void:
	if request_id != _waiting_presentation_id:
		return
	_waiting_presentation_id = -1
	presentation_finished.emit(request_id)


## Requests a visual through signals and waits without referencing UI nodes.
func _present(kind: StringName, actor_index: int = -1, targets: Array[int] = []) -> bool:
	var generation: int = _battle_generation
	if not presentation_requested.has_connections():
		return true
	_next_presentation_id += 1
	var request_id: int = _next_presentation_id
	_waiting_presentation_id = request_id
	presentation_requested.emit(request_id, kind, actor_index, targets)
	while _waiting_presentation_id == request_id and generation == _battle_generation:
		await presentation_finished
	return generation == _battle_generation and is_inside_tree()


## Invalidates pending asynchronous work before retry or scene removal.
func _cancel_presentation() -> void:
	_battle_generation += 1
	var cancelled_id: int = _waiting_presentation_id
	_waiting_presentation_id = -1
	if cancelled_id >= 0:
		presentation_finished.emit(cancelled_id)


## Prevents unfinished visuals from resuming a removed battle.
func _exit_tree() -> void:
	_cancel_presentation()


## Retry battle.
func retry_battle() -> void:
	start_new_battle()


## Request refresh shop.
func request_refresh_shop() -> void:
	if not state.general_cards_enabled or state.phase != BattleState.Phase.PLAYER_TURN:
		return
	if not state.spend_new_toefl(0.5):
		_emit_log(tr("LOG_REFRESH_NO_FUNDS"))
		state_changed.emit(state)
		return
	_roll_shop_offers()
	_emit_log(tr("LOG_SHOP_REFRESHED"))
	state_changed.emit(state)


## Request buy shop card.
func request_buy_shop_card(offer_index: int, character_index: int) -> void:
	if not state.general_cards_enabled or state.phase != BattleState.Phase.PLAYER_TURN:
		return
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


## Request sell general card.
func request_sell_general_card(card_index: int) -> void:
	if not state.general_cards_enabled or state.phase != BattleState.Phase.PLAYER_TURN:
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


## Developer add culture mask.
func developer_add_culture_mask() -> void:
	if not SettingsManager.developer_mode or state.phase != BattleState.Phase.PLAYER_TURN:
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


## Developer add general card.
func developer_add_general_card() -> void:
	if not state.general_cards_enabled or not SettingsManager.developer_mode or state.phase != BattleState.Phase.PLAYER_TURN:
		return
	var card: CardData = GameDataFactory.create_potion_of_confucius()
	card.id = "%s_dev_%d" % [card.id, Time.get_ticks_msec()]
	card.owner_id = "team"
	state.team_general_cards.append(card)
	_emit_log(tr("DEV_LOG_ADDED_CARD"))
	state_changed.emit(state)


## Grant six seven.
func grant_six_seven() -> void:
	if not state.general_cards_enabled:
		return
	var card: CardData = GameDataFactory.create_six_seven()
	if card == null:
		return
	card.id = "%s_hidden_%d" % [card.id, Time.get_ticks_msec()]
	card.owner_id = "team"
	state.team_general_cards.append(card)
	_emit_log(tr("DEV_LOG_ADDED_SIX_SEVEN"))
	state_changed.emit(state)


## Developer clear enemies.
func developer_clear_enemies() -> void:
	if not SettingsManager.developer_mode or state.phase != BattleState.Phase.PLAYER_TURN:
		return
	for enemy: EnemyData in state.enemy_team:
		if enemy.is_alive():
			enemy.current_hp = 0
			_collect_reward_if_dead(enemy)
	_emit_log(tr("DEV_LOG_CLEARED_ENEMIES"))
	_check_battle_end()
	state_changed.emit(state)


## Developer defeat players.
func developer_defeat_players() -> void:
	if not SettingsManager.developer_mode or state.phase != BattleState.Phase.PLAYER_TURN:
		return
	for character: CharacterData in state.player_team:
		if character.is_alive():
			character.current_hp = 0
	_emit_log(tr("DEV_LOG_DEFEATED_PLAYERS"))
	_check_battle_end()
	state_changed.emit(state)


## Skips the current player turn in developer mode and starts the enemy turn.
func developer_skip_turn() -> void:
	if not SettingsManager.developer_mode or state.phase != BattleState.Phase.PLAYER_TURN:
		return
	_emit_log(tr("DEV_LOG_SKIPPED_TURN"))
	for character: CharacterData in state.player_team:
		if character.is_alive():
			character.mark_acted()
	_run_enemy_turn()


## Resolves the card and logs only the resulting battle changes.
func _apply_card_effect(_answer_correct: bool, bonus_triggered: bool) -> void:
	var character: CharacterData = state.selected_character
	var card: CardData = state.pending_card
	if character == null or card == null:
		return

	match card.effect_id:
		"gain_team_ap":
			var gain: float = card.base_ap_gain + state.get_ap_growth_bonus()
			_grant_team_ap(gain)
		"attack_single":
			_apply_attack_card(character, card)
		"attack_single_apply_effect":
			_apply_status_effect_attack(character, card)
		"attack_primary_splash":
			_apply_primary_splash_attack(character, card)
		"attack_ap_pattern":
			_apply_ap_pattern_attack(character, card)
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
			defense_target.add_turn_damage_reduction(block)
			_emit_log(tr("LOG_DEFENSE_GRANTED") % [tr(defense_target.display_name), defense_target.turn_damage_reduction * 100.0])
		"defend_duration":
			_apply_duration_defense(character, card)
		"skill_attack_single", "skill_attack_all":
			_clear_skill_ap()
			_apply_skill_card(character, card)
		"skill_attack_multi_single":
			_clear_skill_ap()
			_apply_multi_single_skill(character, card)
		"skill_chain_debuff":
			_clear_skill_ap()
			_apply_chain_skill(character, card)
		_:
			push_error("BattleManager: unknown card effect_id '%s' for card '%s'." % [card.effect_id, card.id])

	if card.requires_question:
		_gain_question_card_ap(card, bonus_triggered)


## Pays skill AP before hits so newly earned hit bonuses remain available.
func _clear_skill_ap() -> void:
	state.clear_ap()
	_emit_log(tr("LOG_AP_CLEARED"))


## Applies persistent defense independently from question difficulty or correctness.
func _apply_duration_defense(character: CharacterData, card: CardData) -> void:
	var target: CharacterData = state.selected_ally if state.selected_ally != null else character
	var value: float = card.status_effect_value
	var effect: StatusEffectData = EffectDatabase.create_effect(card.status_effect_id, value, card.status_effect_duration, "%s::%s" % [character.id, card.id], card.display_name)
	if effect != null:
		target.apply_status_effect(effect)
		_emit_status_effect_result(target.display_name, effect)


## Chooses the attack pattern once, using AP before this action's gains.
func _apply_ap_pattern_attack(character: CharacterData, card: CardData) -> void:
	var first: EnemyData = state.selected_enemy
	if first == null or not first.is_alive():
		return
	if state.ap < card.ap_switch_threshold:
		var candidates: Array[EnemyData] = state.get_alive_enemies()
		candidates.erase(first)
		var targets: Array[EnemyData] = [first]
		for _target_number in mini(card.extra_target_count, candidates.size()):
			var pick: int = rng.randi_range(0, candidates.size() - 1)
			targets.append(candidates[pick])
			candidates.remove_at(pick)
		for target: EnemyData in targets:
			_deal_player_hit(character, target, _calculate_damage(character, card.base_damage))
	else:
		var target: EnemyData = first
		for index in card.chain_damage_sequence.size():
			if index > 0:
				target = _random_chain_target()
			if target == null or not character.is_alive():
				break
			_deal_player_hit(character, target, _calculate_damage(character, card.chain_damage_sequence[index]))


## Resolves multiple independently defended hits on the originally selected enemy only.
func _apply_multi_single_skill(character: CharacterData, card: CardData) -> void:
	var target: EnemyData = state.selected_enemy
	for _hit in card.hit_count:
		if target == null or not target.is_alive() or not character.is_alive():
			break
		_deal_player_hit(character, target, _calculate_damage(character, card.base_damage))


## Resolves each chain hit before adding one independently rolled status to its survivor.
func _apply_chain_skill(character: CharacterData, card: CardData) -> void:
	var target: EnemyData = state.selected_enemy
	for index in card.hit_count:
		if index > 0:
			target = _random_chain_target()
		if target == null or not target.is_alive() or not character.is_alive():
			break
		_deal_player_hit(character, target, _calculate_damage(character, card.base_damage))
		if target.is_alive() and not card.random_hit_effects.is_empty():
			var option: CardStatusOption = card.random_hit_effects[rng.randi_range(0, card.random_hit_effects.size() - 1)]
			var effect: StatusEffectData = EffectDatabase.create_effect(option.effect_id, option.value, option.duration, "%s::%s" % [character.id, card.id], card.display_name)
			if effect != null and target.apply_status_effect(effect):
				_emit_status_effect_result(target.display_name, effect)


## Includes the previous enemy among living candidates, allowing stationary chain bounces.
func _random_chain_target() -> EnemyData:
	var candidates: Array[EnemyData] = state.get_alive_enemies()
	return candidates[rng.randi_range(0, candidates.size() - 1)] if not candidates.is_empty() else null


## Resolves a player hit, grants preexisting AP marks once per hit, and collects death rewards once.
func _deal_player_hit(character: CharacterData, enemy: EnemyData, damage: int) -> int:
	if not enemy.is_alive() or not character.is_alive():
		return 0
	var ap_bonus: float = 0.0
	for effect: StatusEffectData in enemy.active_effects:
		if effect.id == "attack_ap" and effect.is_active():
			ap_bonus += effect.value
	var before_hp: int = enemy.current_hp
	var dealt: int = enemy.take_damage(damage)
	if enemy.last_damage_was_immune:
		_emit_log(tr("LOG_DAMAGE_IMMUNED") % [tr(enemy.display_name), tr(character.display_name)])
	else:
		_emit_log(tr("LOG_ATTACK_DAMAGE") % [tr(character.display_name), tr(enemy.display_name), dealt])
	if ap_bonus > 0.0:
		_grant_team_ap(ap_bonus + state.get_ap_growth_bonus())
	_collect_reward_if_dead(enemy)
	_resolve_enemy_retaliation(enemy, character, before_hp - enemy.current_hp)
	return dealt


## Returns copied counterattack damage directly, without recursively invoking either side's retaliation.
func _resolve_enemy_retaliation(enemy: EnemyData, target: CharacterData, hp_lost: int) -> void:
	if hp_lost <= 0:
		return
	var reflection: float = 0.0
	for effect: StatusEffectData in enemy.active_effects:
		if not effect.is_active():
			continue
		if effect.id == "counterattack":
			reflection = maxf(reflection, effect.value)
	_grant_enemy_hurt_ap(enemy, hp_lost)
	if reflection > 0.0 and target.is_alive():
		var before_hp: int = target.current_hp
		target.take_damage(roundi(float(hp_lost) * reflection))
		_record_player_hit(target)
		if target.last_damage_was_immune:
			_emit_log(tr("LOG_DAMAGE_IMMUNED") % [tr(target.display_name), tr(enemy.display_name)])
		else:
			_emit_log(tr("LOG_REFLECT_DAMAGE") % [tr(enemy.display_name), tr(target.display_name), before_hp - target.current_hp])
		_grant_player_hurt_ap(target, before_hp - target.current_hp)


## Grants an enemy's copied AP-on-hurt bonus for positive HP damage without retaliation recursion.
func _grant_enemy_hurt_ap(enemy: EnemyData, hp_lost: int) -> void:
	if hp_lost <= 0:
		return
	var gain: float = 0.0
	for effect: StatusEffectData in enemy.active_effects:
		if effect.id == "hurt_ap" and effect.is_active():
			gain += effect.value
	var previous: float = enemy.ap
	enemy.ap = minf(5.0, enemy.ap + gain)
	if enemy.ap > previous:
		_emit_log(tr("LOG_UNIT_GAIN_AP") % [tr(enemy.display_name), enemy.ap - previous])


## Grants allied AP-on-hurt for actual HP damage, including returned attacks.
func _grant_player_hurt_ap(target: CharacterData, hp_lost: int) -> void:
	if hp_lost <= 0:
		return
	var gain: float = 0.0
	for effect: StatusEffectData in target.active_effects:
		if effect.id == "hurt_ap" and effect.is_active():
			gain += effect.value
	if gain > 0.0:
		_grant_team_ap(gain + state.get_ap_growth_bonus())


## Apply attack card.
func _apply_attack_card(character: CharacterData, card: CardData) -> void:
	var enemy: EnemyData = state.selected_enemy
	if enemy == null:
		return
	var damage: int = _calculate_damage(character, card.base_damage)
	_deal_player_hit(character, enemy, damage)


## Applies the attack status and reports its value without its source.
func _apply_status_effect_attack(character: CharacterData, card: CardData) -> void:
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
	if effect != null and enemy.apply_status_effect(effect):
		_emit_status_effect_result(enemy.display_name, effect)
	_apply_attack_card(character, card)


## Apply primary splash attack.
func _apply_primary_splash_attack(character: CharacterData, card: CardData) -> void:
	var primary_target: EnemyData = state.selected_enemy
	if primary_target == null:
		return
	for enemy: EnemyData in state.enemy_team:
		if not enemy.is_alive():
			continue
		var base_damage: int = card.base_damage if enemy == primary_target else roundi(float(card.base_damage) * 0.5)
		var damage: int = _calculate_damage(character, base_damage)
		_deal_player_hit(character, enemy, damage)


## Resolves percentage damage and reports only the actual hit result.
func _apply_current_hp_percent_damage(character: CharacterData, card: CardData) -> void:
	var enemy: EnemyData = state.selected_enemy
	if enemy == null:
		return
	var target_hp_before: int = enemy.current_hp
	var dynamic_base_damage: int = maxi(1, roundi(float(target_hp_before) * card.current_hp_damage_ratio))
	var damage: int = _calculate_damage(character, dynamic_base_damage)
	_deal_player_hit(character, enemy, damage)


## Applies an allied status and reports its value without naming the card.
func _apply_status_to_ally(character: CharacterData, card: CardData) -> void:
	var target: CharacterData = state.selected_ally if state.selected_ally != null else character
	var effect: StatusEffectData = _create_card_status_effect(character, card)
	if target == null or effect == null:
		return
	target.apply_status_effect(effect)
	_emit_status_effect_result(target.display_name, effect)


## Reports the enemy's status change or unchanged state without provenance.
func _apply_status_to_enemy(character: CharacterData, card: CardData) -> void:
	var target: EnemyData = state.selected_enemy
	var effect: StatusEffectData = _create_card_status_effect(character, card)
	if target == null or effect == null:
		return
	if target.apply_status_effect(effect):
		_emit_status_effect_result(target.display_name, effect)
	else:
		_emit_log(tr("LOG_STATUS_UNCHANGED") % tr(target.display_name))


## Reports the target's actual restored HP without naming the healing source.
func _apply_max_hp_percent_heal(character: CharacterData, card: CardData) -> void:
	var target: CharacterData = state.selected_ally if state.selected_ally != null else character
	if target == null:
		return
	var requested_heal: int = roundi(float(target.max_hp) * card.max_hp_heal_ratio)
	var healed: int = target.heal(requested_heal)
	_emit_log(tr("LOG_MAX_HP_HEAL") % [tr(target.display_name), healed])


## Reports immediate and scheduled stat changes without naming their source.
func _apply_gall_of_goujian(character: CharacterData, card: CardData) -> void:
	var target: CharacterData = state.selected_ally if state.selected_ally != null else character
	if target == null:
		return
	var weakness: StatusEffectData = target.get_status_effect_from_card("weakness", card.id)
	if weakness != null and weakness.is_active():
		_emit_log(tr("LOG_STATUS_UNCHANGED") % tr(target.display_name))
		return
	var strength: StatusEffectData = target.get_status_effect_from_card("strength", card.id)
	if strength != null and strength.is_active():
		strength.remaining_turns = card.secondary_status_effect_duration
		_emit_status_effect_result(target.display_name, strength)
		return

	var weakness_effect: StatusEffectData = _create_card_status_effect(character, card)
	var strength_effect: StatusEffectData = _create_secondary_card_status_effect(character, card)
	target.apply_status_effect(weakness_effect)
	target.apply_status_effect(strength_effect)
	_emit_status_effect_result(target.display_name, weakness_effect)
	_emit_status_effect_result(target.display_name, strength_effect)


## Reports each applied stat change separately with its configured value.
func _apply_dual_status_to_ally(character: CharacterData, card: CardData) -> void:
	var target: CharacterData = state.selected_ally if state.selected_ally != null else character
	if target == null:
		return
	var primary_effect: StatusEffectData = _create_card_status_effect(character, card)
	var secondary_effect: StatusEffectData = _create_secondary_card_status_effect(character, card)
	if primary_effect != null:
		target.apply_status_effect(primary_effect)
		_emit_status_effect_result(target.display_name, primary_effect)
	if secondary_effect != null:
		target.apply_status_effect(secondary_effect)
		_emit_status_effect_result(target.display_name, secondary_effect)


## Reports only the target's actual direct HP loss.
func _apply_direct_hp_loss(character: CharacterData, card: CardData) -> void:
	var target: CharacterData = state.selected_ally if state.selected_ally != null else character
	if target == null:
		return
	var lost_hp: int = target.lose_hp_direct(card.direct_hp_loss)
	_emit_log(tr("LOG_DIRECT_HP_LOSS") % [tr(target.display_name), lost_hp])


## Create card status effect.
func _create_card_status_effect(character: CharacterData, card: CardData) -> StatusEffectData:
	return EffectDatabase.create_effect(
		card.status_effect_id,
		card.status_effect_value,
		card.status_effect_duration,
		"%s::%s" % [character.id, card.id],
		card.display_name,
		card.status_effect_delay
	)


## Create secondary card status effect.
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


## Reports skill damage using the same concise hit format as other attacks.
func _apply_skill_card(character: CharacterData, card: CardData) -> void:
	if card.target_type == CardData.TargetType.ALL_ENEMIES:
		for enemy: EnemyData in state.enemy_team:
			if enemy.is_alive():
				var damage: int = _calculate_damage(character, card.base_damage)
				_deal_player_hit(character, enemy, damage)
	else:
		var enemy: EnemyData = state.selected_enemy
		if enemy != null:
			var damage: int = _calculate_damage(character, card.base_damage)
			_deal_player_hit(character, enemy, damage)


## Calculate damage.
func _calculate_damage(character: CharacterData, base_damage: int) -> int:
	var multiplier: float = state.get_team_stat_multiplier()
	return maxi(1, roundi(float(base_damage) * multiplier * character.get_outgoing_damage_multiplier()))


## Grants action AP without narrating the answer or its bonus source.
func _gain_question_card_ap(card: CardData, bonus_triggered: bool) -> void:
	var difficulty_bonus: float = card.get_correct_answer_ap_bonus(state.pending_difficulty) if bonus_triggered else 0.0
	var gain: float = card.base_ap_gain + difficulty_bonus
	if gain > 0.0:
		_grant_team_ap(gain + state.get_ap_growth_bonus())


## Reports the actual AP gained after applying the existing team cap.
func _grant_team_ap(amount: float) -> void:
	var previous_ap: float = state.ap
	state.add_ap(amount)
	var gained_ap: float = state.ap - previous_ap
	if gained_ap > 0.0:
		_emit_log(tr("LOG_TEAM_GAIN_AP") % gained_ap)


## Finish player action.
func _finish_player_action() -> void:
	if state.selected_character != null:
		state.selected_character.mark_acted()
		if state.pending_card != null and state.pending_card.is_general():
			var used_card_index: int = state.team_general_cards.find(state.pending_card)
			if used_card_index != -1:
				state.team_general_cards.remove_at(used_card_index)
	state.clear_pending_action()
	if state.ap >= 5.0:
		_emit_tutorial_tip("skill")

	if _check_battle_end():
		state_changed.emit(state)
		return

	if state.did_all_living_players_act():
		await _run_enemy_turn()
	else:
		state.phase = BattleState.Phase.PLAYER_TURN
		state_changed.emit(state)


## Announces the enemy turn and resolves enemies sequentially, waiting for each visual.
func _run_enemy_turn() -> void:
	state.phase = BattleState.Phase.ENEMY_TURN
	state_changed.emit(state)
	_emit_log(tr("LOG_ENEMY_TURN_START"))
	_emit_tutorial_tip("enemy_turn")
	if not await _present(&"enemy_turn"):
		return

	for enemy: EnemyData in state.enemy_team:
		if not enemy.is_alive():
			continue
		var enemy_index: int = state.enemy_team.find(enemy)
		if enemy.consume_all_status_effects("stun") > 0:
			_emit_log(tr("LOG_ENEMY_STUNNED") % tr(enemy.display_name))
			state_changed.emit(state)
			if not await _present(&"enemy_skip", enemy_index):
				return
			continue
		var ability: EnemyAbilityData = null
		var chosen_card: CardData = null
		var is_attack: bool = false
		if enemy.is_charging():
			var target_index: int = enemy.charge_target_index
			is_attack = enemy.charge_remaining_turns <= 1 and target_index >= 0 and target_index < state.player_team.size() and state.player_team[target_index].is_alive()
		else:
			ability = enemy.choose_ability(rng)
			if ability == null:
				continue
			is_attack = ability.id in ["bun_group_attack", "single_attack", "nian_weakening_strike"]
			if ability.id in ["copy_player_card", "use_general_card"]:
				chosen_card = _choose_enemy_card(ability)
				if chosen_card == null:
					continue
				is_attack = chosen_card.base_damage > 0 or chosen_card.effect_id == "damage_current_hp_percent"
		var kind: StringName = &"enemy_attack" if is_attack else &"enemy_action"
		if not await _present(kind, enemy_index):
			return
		_hit_player_indices.clear()
		_run_enemy_action(enemy, ability, chosen_card)
		state_changed.emit(state)
		if not _hit_player_indices.is_empty():
			if not await _present(&"player_hurt", -1, _hit_player_indices.duplicate()):
				return
		if _check_battle_end():
			state_changed.emit(state)
			return

	_start_player_turn()
	_emit_log(tr("LOG_NEXT_PLAYER_TURN") % state.turn_count)
	_emit_tutorial_tip("next_turn")
	if state.did_all_living_players_act():
		state.phase = BattleState.Phase.ENEMY_TURN
		_continue_skipped_turn.call_deferred(_battle_generation)
	state_changed.emit(state)


## Starts a player turn and consumes stuns as skipped character actions.
func _start_player_turn() -> void:
	state.start_player_turn()
	for character: CharacterData in state.get_alive_players():
		if character.consume_active_stuns():
			character.mark_acted()
			_emit_log(tr("LOG_PLAYER_STUNNED") % tr(character.display_name))


## Advances an entirely stunned team without recursion or reviving a cancelled battle.
func _continue_skipped_turn(generation: int) -> void:
	if generation == _battle_generation and state.phase == BattleState.Phase.ENEMY_TURN:
		_run_enemy_turn()


## Resolves the ability already selected for this enemy's visible action.
func _run_enemy_action(enemy: EnemyData, ability: EnemyAbilityData, chosen_card: CardData = null) -> void:
	if enemy.is_charging():
		_run_nian_charge_progress(enemy)
		return
	if ability == null:
		return
	match ability.id:
		"slime_team_shield":
			_run_slime_support(enemy, ability.power)
		"bun_group_attack":
			_run_bun_group_attack(enemy, ability.power)
		"single_attack":
			_run_single_attack(enemy, ability.power)
		"nian_weakening_strike":
			_run_nian_weakening_strike(enemy, ability.power)
		"nian_charge_attack":
			_start_nian_charge(enemy, ability.power)
		"copy_player_card", "use_general_card":
			_apply_enemy_card(enemy, chosen_card)
		_:
			push_error("BattleManager: unknown enemy ability '%s' for '%s'." % [ability.id, enemy.id])


## Chooses an allied non-skill card or an explicit enemy pool without using player unlock gates.
func _choose_enemy_card(ability: EnemyAbilityData) -> CardData:
	var cards: Array[CardData] = []
	if ability.id == "copy_player_card":
		for character: CharacterData in state.get_alive_players():
			for card: CardData in character.cards:
				if card.card_type in [CardData.CardType.ATTACK, CardData.CardType.DEFENSE]:
					cards.append(card)
	else:
		cards = CardDatabase.create_cards(ability.card_ids)
	return cards[rng.randi_range(0, cards.size() - 1)] if not cards.is_empty() else null


## Creates enemy-phase statuses that remain active through the upcoming player turn.
func _enemy_card_status(enemy: EnemyData, card: CardData, secondary: bool = false) -> StatusEffectData:
	var effect_id: String = card.secondary_status_effect_id if secondary else card.status_effect_id
	if effect_id.is_empty():
		return null
	var value: float = card.secondary_status_effect_value if secondary else card.status_effect_value
	var duration: int = card.secondary_status_effect_duration if secondary else card.status_effect_duration
	var delay: int = card.secondary_status_effect_delay if secondary else card.status_effect_delay
	var effect: StatusEffectData = EffectDatabase.create_effect(effect_id, value, duration, "%s::%s" % [enemy.id, card.id], card.display_name, delay)
	if effect != null:
		effect.skip_next_turn_tick = true
	return effect


## Applies a self-targeted copied status and reports its resulting value without card narration.
func _apply_enemy_self_status(enemy: EnemyData, effect: StatusEffectData) -> void:
	if effect != null and enemy.apply_status_effect(effect):
		_emit_status_effect_result(enemy.display_name, effect)


## Mirrors card effects onto the enemy's own side or random living player targets.
func _apply_enemy_card(enemy: EnemyData, card: CardData) -> void:
	if card == null:
		return
	match card.effect_id:
		"attack_single", "attack_single_apply_effect":
			var target: CharacterData = _get_random_alive_player()
			if target == null:
				return
			if card.effect_id == "attack_single_apply_effect":
				var effect: StatusEffectData = _enemy_card_status(enemy, card)
				if effect != null:
					target.apply_status_effect(effect)
					_emit_status_effect_result(target.display_name, effect)
			_resolve_enemy_hit(enemy, target, card.base_damage)
		"attack_ap_pattern":
			_apply_enemy_ap_attack(enemy, card)
		"attack_primary_splash":
			var primary: CharacterData = _get_random_alive_player()
			for target: CharacterData in state.get_alive_players():
				if not enemy.is_alive():
					break
				_resolve_enemy_hit(enemy, target, card.base_damage if target == primary else roundi(float(card.base_damage) * 0.5))
		"defend_duration", "defend_single":
			var value: float = card.status_effect_value if card.effect_id == "defend_duration" else card.base_block
			var duration: int = maxi(1, card.status_effect_duration)
			var effect: StatusEffectData = EffectDatabase.create_effect("damage_reduction", value, duration, "%s::%s" % [enemy.id, card.id], card.display_name)
			effect.skip_next_turn_tick = true
			_apply_enemy_self_status(enemy, effect)
		"apply_status_ally":
			_apply_enemy_self_status(enemy, _enemy_card_status(enemy, card))
		"apply_dual_status_ally":
			_apply_enemy_self_status(enemy, _enemy_card_status(enemy, card))
			_apply_enemy_self_status(enemy, _enemy_card_status(enemy, card, true))
		"damage_current_hp_percent":
			var target: CharacterData = _get_random_alive_player()
			if target != null:
				_resolve_enemy_hit(enemy, target, maxi(1, roundi(float(target.current_hp) * card.current_hp_damage_ratio)))
		"apply_status_enemy":
			var target: CharacterData = _get_random_alive_player()
			var effect: StatusEffectData = _enemy_card_status(enemy, card)
			if target != null and effect != null:
				target.apply_status_effect(effect)
				_emit_status_effect_result(target.display_name, effect)
		"heal_max_hp_percent":
			var healed: int = enemy.heal(roundi(float(enemy.max_hp) * card.max_hp_heal_ratio))
			_emit_log(tr("LOG_MAX_HP_HEAL") % [tr(enemy.display_name), healed])
		"gall_of_goujian":
			var weakness: StatusEffectData = enemy.get_status_effect_from_source("weakness", "%s::%s" % [enemy.id, card.id])
			var strength: StatusEffectData = enemy.get_status_effect_from_source("strength", "%s::%s" % [enemy.id, card.id])
			if weakness != null and weakness.is_active():
				_emit_log(tr("LOG_STATUS_UNCHANGED") % tr(enemy.display_name))
			elif strength != null and strength.is_active():
				strength.remaining_turns = card.secondary_status_effect_duration
				strength.skip_next_turn_tick = true
				_emit_status_effect_result(enemy.display_name, strength)
			else:
				_apply_enemy_self_status(enemy, _enemy_card_status(enemy, card))
				_apply_enemy_self_status(enemy, _enemy_card_status(enemy, card, true))
		_:
			push_error("BattleManager: unsupported copied card effect '%s'." % card.effect_id)


## Samples player AP once and mirrors unique multi-target or repeatable chain attacks.
func _apply_enemy_ap_attack(enemy: EnemyData, card: CardData) -> void:
	var first: CharacterData = _get_random_alive_player()
	if first == null:
		return
	if state.ap < card.ap_switch_threshold:
		var candidates: Array[CharacterData] = state.get_alive_players()
		candidates.erase(first)
		var targets: Array[CharacterData] = [first]
		for _index in mini(card.extra_target_count, candidates.size()):
			var index: int = rng.randi_range(0, candidates.size() - 1)
			targets.append(candidates[index])
			candidates.remove_at(index)
		for target: CharacterData in targets:
			if not enemy.is_alive():
				break
			_resolve_enemy_hit(enemy, target, card.base_damage)
	else:
		var target: CharacterData = first
		for index in card.chain_damage_sequence.size():
			if index > 0:
				target = _get_random_alive_player()
			if target == null or not enemy.is_alive():
				break
			_resolve_enemy_hit(enemy, target, card.chain_damage_sequence[index])


## Grants maximum-value shields without stacking and logs only actual increases.
func _run_slime_support(_enemy: EnemyData, power: int) -> void:
	var shield_amount: int = maxi(0, power)
	for ally: EnemyData in state.enemy_team:
		if ally.is_alive():
			var gained: int = ally.grant_max_shield(shield_amount)
			if gained > 0:
				_emit_log(tr("LOG_UNIT_SHIELD_GAIN") % [tr(ally.display_name), gained])


## Stops a group attack if an earlier target's retaliation kills its attacker.
func _run_bun_group_attack(enemy: EnemyData, power: int) -> void:
	for target: CharacterData in state.get_alive_players():
		if not enemy.is_alive():
			break
		_resolve_enemy_hit(enemy, target, power)


## Delivers a single attack through shared weakness, damage, and retaliation resolution.
func _run_single_attack(enemy: EnemyData, power: int) -> void:
	var target: CharacterData = _get_random_alive_player()
	if target == null:
		return
	_resolve_enemy_hit(enemy, target, power)


## Reports weakness independently from the attack, including attacks blocked by immunity.
func _run_nian_weakening_strike(enemy: EnemyData, power: int) -> void:
	var target: CharacterData = _get_random_alive_player()
	if target == null:
		return
	var effect: StatusEffectData = EffectDatabase.create_effect(
		"weakness",
		0.30,
		2,
		"%s::nian_weakening_strike" % enemy.id,
		"ENEMY_ABILITY_NIAN_WEAKENING_STRIKE"
	)
	effect.skip_next_turn_tick = true
	target.apply_status_effect(effect)
	_emit_status_effect_result(target.display_name, effect)
	_resolve_enemy_hit(enemy, target, power)


## Starts Nian Beast's charged attack and locks its chosen target.
func _start_nian_charge(enemy: EnemyData, power: int) -> void:
	var target_index: int = _get_random_alive_player_index()
	if target_index == -1:
		return
	var target: CharacterData = state.player_team[target_index]
	enemy.start_charge("nian_charge_attack", power, target_index, 2, target.display_name, target.portrait_path)
	_emit_log(tr("LOG_NIAN_CHARGE_START") % [tr(enemy.display_name), tr(target.display_name)])


## Advances charging and reports only remaining time, cancellation, or the resulting hit.
func _run_nian_charge_progress(enemy: EnemyData) -> void:
	var target_index: int = enemy.charge_target_index
	if target_index < 0 or target_index >= state.player_team.size():
		enemy.clear_charge()
		return
	var target: CharacterData = state.player_team[target_index]
	if not target.is_alive():
		_emit_log(tr("LOG_NIAN_CHARGE_TARGET_LOST") % tr(enemy.display_name))
		enemy.clear_charge()
		return
	var remaining_turns: int = enemy.advance_charge()
	if remaining_turns > 0:
		_emit_log(tr("LOG_NIAN_CHARGING") % [tr(enemy.display_name), remaining_turns])
		return
	_resolve_enemy_hit(enemy, target, enemy.charge_power)
	enemy.clear_charge()


## Applies actual HP damage before AP-on-hurt and unamplified retaliation, including lethal hits.
func _resolve_enemy_hit(enemy: EnemyData, target: CharacterData, power: int) -> void:
	var hp_before: int = target.current_hp
	var damage: int = roundi(float(maxi(0, power)) * enemy.get_outgoing_damage_multiplier())
	target.take_damage(damage)
	var hp_lost: int = hp_before - target.current_hp
	_record_player_hit(target)
	if target.last_damage_was_immune:
		_emit_log(tr("LOG_DAMAGE_IMMUNED") % [tr(target.display_name), tr(enemy.display_name)])
	else:
		_emit_log(tr("LOG_ENEMY_ATTACK") % [tr(enemy.display_name), tr(target.display_name), hp_lost])
	if hp_lost <= 0:
		return
	var reflection: float = 0.0
	for effect: StatusEffectData in target.active_effects:
		if not effect.is_active():
			continue
		if effect.id == "counterattack":
			reflection = maxf(reflection, effect.value)
	_grant_player_hurt_ap(target, hp_lost)
	if reflection > 0.0 and enemy.is_alive():
		var before: int = enemy.current_hp
		var reflected: int = enemy.take_damage(roundi(float(hp_lost) * reflection))
		_emit_log(tr("LOG_REFLECT_DAMAGE") % [tr(target.display_name), tr(enemy.display_name), reflected])
		_grant_enemy_hurt_ap(enemy, before - enemy.current_hp)
		_collect_reward_if_dead(enemy)


## Records attacked players, including shielded and lethal hits, for one-shot hurt playback.
func _record_player_hit(target: CharacterData) -> void:
	var index: int = state.player_team.find(target)
	if index >= 0 and not _hit_player_indices.has(index):
		_hit_player_indices.append(index)


## Settles victory currency exactly once before persisting mainline progression.
func _check_battle_end() -> bool:
	if state.phase in [BattleState.Phase.VICTORY, BattleState.Phase.DEFEAT]:
		return true
	if state.are_all_enemies_dead():
		if state.current_wave < state.total_waves:
			_start_next_wave()
			return true
		state.phase = BattleState.Phase.VICTORY
		_emit_tutorial_tip("victory")
		var old_gained: int = 0
		if not state.currency_settled:
			state.currency_settled = true
			old_gained = SaveManager.settle_battle_currency(state.new_toefl)
			_emit_log(tr("LOG_CURRENCY_CONVERTED") % [state.new_toefl, old_gained])
		SaveManager.advance_after_level_clear(active_level.id)
		result_requested.emit(tr("RESULT_VICTORY_TITLE"), tr("RESULT_VICTORY_MESSAGE") % old_gained, true, true)
		return true
	if state.are_all_players_dead():
		state.phase = BattleState.Phase.DEFEAT
		result_requested.emit(tr("RESULT_DEFEAT_TITLE"), tr("RESULT_DEFEAT_MESSAGE"), true, false)
		return true
	return false


## Start next wave.
func _start_next_wave() -> void:
	var next_wave_index: int = state.current_wave
	var next_enemies: Array[EnemyData] = GameDataFactory.create_level_wave(active_level, next_wave_index, rng)
	state.replace_enemy_wave(next_enemies, state.current_wave + 1)
	_start_player_turn()
	_emit_log(tr("LOG_WAVE_START") % [state.current_wave, state.total_waves])
	_emit_log(tr("LOG_NEXT_PLAYER_TURN") % state.turn_count)


## Collect reward if dead.
func _collect_reward_if_dead(enemy: EnemyData) -> void:
	if enemy.is_alive() or enemy.rewards_collected:
		return
	enemy.rewards_collected = true

	if enemy.toefl_reward > 0.0:
		var before: float = state.new_toefl
		state.add_new_toefl(enemy.toefl_reward)
		_emit_log(tr("LOG_ENEMY_REWARD") % [tr(enemy.display_name), state.new_toefl - before])

	if not state.general_cards_enabled:
		return
	var dropped_card: CardData = GameDataFactory.create_enemy_drop_general_card(rng)
	if dropped_card != null:
		dropped_card.owner_id = "team"
		state.team_general_cards.append(dropped_card)
		_emit_log(tr("LOG_ENEMY_CARD_DROP") % [tr(enemy.display_name), tr(dropped_card.display_name)])


## Get enemy or first alive.
func _get_enemy_or_first_alive(index: int) -> EnemyData:
	if index >= 0 and index < state.enemy_team.size() and state.enemy_team[index].is_alive():
		return state.enemy_team[index]
	for enemy: EnemyData in state.enemy_team:
		if enemy.is_alive():
			return enemy
	return null


## Get ally or actor.
func _get_ally_or_actor(index: int, actor: CharacterData) -> CharacterData:
	if index >= 0 and index < state.player_team.size() and state.player_team[index].is_alive():
		return state.player_team[index]
	return actor if actor != null and actor.is_alive() else null


## Get random alive player.
func _get_random_alive_player() -> CharacterData:
	var alive := state.get_alive_players()
	if alive.is_empty():
		return null
	return alive[rng.randi_range(0, alive.size() - 1)]


## Returns a random alive player index for effects that must keep a fixed target.
func _get_random_alive_player_index() -> int:
	var alive_indices: Array[int] = []
	for i in state.player_team.size():
		if state.player_team[i].is_alive():
			alive_indices.append(i)
	if alive_indices.is_empty():
		return -1
	return alive_indices[rng.randi_range(0, alive_indices.size() - 1)]


## Card needs enemy.
func _card_needs_enemy(card: CardData) -> bool:
	return card.targets_single_enemy()


## Card needs ally.
func _card_needs_ally(card: CardData) -> bool:
	return card.targets_ally()


## Describes the affected unit's status value and timing without card or actor provenance.
func _emit_status_effect_result(target_name: String, effect: StatusEffectData) -> void:
	if effect == null:
		return
	var message: String = ""
	var name_text: String = tr(target_name)
	match effect.id:
		"weakness":
			message = tr("LOG_ATTACK_REDUCED") % [name_text, effect.value * 100.0, effect.remaining_turns]
		"strength":
			message = tr("LOG_ATTACK_INCREASED") % [name_text, effect.value * 100.0, effect.remaining_turns]
		"vulnerable":
			message = tr("LOG_INCOMING_DAMAGE_INCREASED") % [name_text, effect.value * 100.0, effect.remaining_turns]
		"damage_immunity":
			message = tr("LOG_IMMUNITY_GAINED") % [name_text, maxi(1, roundi(effect.value))]
		"stun":
			message = tr("LOG_STUN_APPLIED") % [name_text, effect.remaining_turns]
		"damage_reduction":
			message = tr("LOG_DAMAGE_REDUCTION_DURATION") % [name_text, effect.value * 100.0, effect.remaining_turns]
		"counterattack":
			message = tr("LOG_COUNTERATTACK_GRANTED") % [name_text, effect.value * 100.0, effect.remaining_turns]
		"hurt_ap":
			message = tr("LOG_HURT_AP_GRANTED") % [name_text, effect.value, effect.remaining_turns]
		"attack_ap":
			message = tr("LOG_ATTACK_AP_MARKED") % [name_text, effect.value, effect.remaining_turns]
		_:
			if effect.value_format == "percent":
				message = tr("LOG_STATUS_PERCENT") % [name_text, tr(effect.display_name), effect.value * 100.0, effect.remaining_turns]
			else:
				message = tr("LOG_STATUS_APPLIED") % [name_text, tr(effect.display_name), effect.remaining_turns]
	if effect.delay_turns > 0:
		message = tr("LOG_STATUS_DELAYED") % [effect.delay_turns, message]
	_emit_log(message)


## Stores the already formatted outcome and updates the log view.
func _emit_log(message: String) -> void:
	state.push_log(message)
	log_added.emit(message)


## Roll shop offers.
func _roll_shop_offers() -> void:
	if not state.general_cards_enabled:
		state.shop_offer_cards.clear()
		return
	state.shop_offer_cards = GameDataFactory.create_shop_general_offers(rng, 4)


## Writes each configured lesson once per attempt and notifies the existing log UI.
func _emit_tutorial_tip(step: String) -> void:
	if state.tutorial == null or state.tutorial_steps_seen.has(step):
		return
	var key: String = state.tutorial.get_battle_message(step)
	if key.is_empty():
		return
	var speaker: CharacterData = CharacterDatabase.create_character(state.tutorial.speaker_id)
	if speaker == null:
		return
	state.tutorial_steps_seen[step] = true
	state.tutorial_log_unread = true
	_emit_log(tr("TUTORIAL_SPEAKER_FORMAT") % [tr(speaker.display_name), tr(key)])


## Clears the log reminder without rebuilding cards or changing combat state.
func notify_tutorial_log_opened() -> void:
	if not state.tutorial_log_unread:
		return
	state.tutorial_log_unread = false
	log_added.emit("")


## Get card for request.
func _get_card_for_request(character: CharacterData, card_index: int) -> CardData:
	if _is_team_general_card_index(card_index):
		var team_card_index: int = _decode_team_general_card_index(card_index)
		if team_card_index >= 0 and team_card_index < state.team_general_cards.size():
			return state.team_general_cards[team_card_index]
		return null
	if card_index >= 0 and card_index < character.cards.size():
		return character.cards[card_index]
	return null


## Is team general card index.
func _is_team_general_card_index(card_index: int) -> bool:
	return card_index <= -TEAM_GENERAL_CARD_INDEX_OFFSET


## Decode team general card index.
func _decode_team_general_card_index(card_index: int) -> int:
	return -card_index - TEAM_GENERAL_CARD_INDEX_OFFSET
