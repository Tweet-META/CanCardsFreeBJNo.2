extends RefCounted
## 一局战斗的唯一可变状态容器，不负责 UI，也不主动推进回合。
class_name BattleState

enum Phase {
	SETUP,
	PLAYER_TURN,
	DIFFICULTY_SELECTION,
	QUESTION,
	ENEMY_TURN,
	VICTORY,
	DEFEAT
}

const ATTRIBUTE_PINYIN: String = LearningAttribute.PINYIN
const ATTRIBUTE_VOCABULARY: String = LearningAttribute.VOCABULARY
const ATTRIBUTE_CULTURE: String = LearningAttribute.CULTURE

var phase: Phase = Phase.SETUP
# 选择目标与 pending_* 字段共同描述一张正在结算的卡牌。
var turn_count: int = 0
var level_id: String = ""
var battle_background: String = ""
var current_wave: int = 1
var total_waves: int = 1
var player_team: Array[CharacterData] = []
var enemy_team: Array[EnemyData] = []
var selected_character: CharacterData
var selected_ally: CharacterData
var selected_enemy: EnemyData
var pending_card: CardData
var pending_question: QuestionData
var pending_difficulty: String = "easy"
var ap: float = 0.0
var new_toefl: float = 0.0
var team_general_cards: Array[CardData] = []
var shop_offer_cards: Array[CardData] = []
var battle_log: Array[String] = []


func setup(players: Array[CharacterData], enemies: Array[EnemyData], level: LevelData, rng: RandomNumberGenerator = null) -> void:
	# 拼音生命被动按开战阵容计算一次；角色倒下不会缩减已经获得的最大生命。
	player_team = players
	enemy_team = enemies
	level_id = level.id
	battle_background = level.battle_background
	current_wave = 1
	total_waves = maxi(1, level.waves.size())
	phase = Phase.SETUP
	turn_count = 0
	ap = 0.0
	new_toefl = 0.0
	team_general_cards = GameDataFactory.create_starting_general_cards(rng)
	shop_offer_cards.clear()
	battle_log.clear()

	var pinyin_passive_count: int = get_attribute_count(ATTRIBUTE_PINYIN, false)
	var max_hp_multiplier: float = 1.0 + float(pinyin_passive_count) * 0.20
	for character: CharacterData in player_team:
		character.setup_runtime(max_hp_multiplier)
	for enemy: EnemyData in enemy_team:
		enemy.setup_runtime()


func replace_enemy_wave(enemies: Array[EnemyData], wave_number: int) -> void:
	# 波次切换只替换敌方运行实例，不重置我方、卡牌、AP、货币或商店。
	enemy_team = enemies
	current_wave = clampi(wave_number, 1, total_waves)
	for enemy: EnemyData in enemy_team:
		enemy.setup_runtime()


func start_player_turn() -> void:
	# 新回合会清空临时选择，并恢复存活角色的行动资格与回合减伤。
	phase = Phase.PLAYER_TURN
	turn_count += 1
	selected_character = null
	selected_ally = null
	selected_enemy = null
	pending_card = null
	pending_question = null
	pending_difficulty = "easy"

	for character: CharacterData in player_team:
		if character.is_alive():
			character.reset_turn_state()
			character.advance_status_effect_turns()
	for enemy: EnemyData in enemy_team:
		if enemy.is_alive():
			enemy.advance_status_effect_turns()


func get_alive_players() -> Array[CharacterData]:
	var alive: Array[CharacterData] = []
	for character: CharacterData in player_team:
		if character.is_alive():
			alive.append(character)
	return alive


func get_alive_enemies() -> Array[EnemyData]:
	var alive: Array[EnemyData] = []
	for enemy: EnemyData in enemy_team:
		if enemy.is_alive():
			alive.append(enemy)
	return alive


func are_all_players_dead() -> bool:
	return get_alive_players().is_empty()


func are_all_enemies_dead() -> bool:
	return get_alive_enemies().is_empty()


func did_all_living_players_act() -> bool:
	for character: CharacterData in player_team:
		if character.is_alive() and not character.has_acted:
			return false
	return true


func get_pinyin_passive_count() -> int:
	return get_attribute_count(ATTRIBUTE_PINYIN)


func get_vocabulary_passive_count() -> int:
	return get_attribute_count(ATTRIBUTE_VOCABULARY)


func get_culture_passive_count() -> int:
	return get_attribute_count(ATTRIBUTE_CULTURE)


func get_attribute_count(attribute: String, alive_only: bool = true) -> int:
	# 所有属性被动都通过这个入口统计，因此新增同属性角色会自然叠加。
	var count: int = 0
	for character: CharacterData in player_team:
		if character.attribute != attribute:
			continue
		if alive_only and not character.is_alive():
			continue
		count += 1
	return count

func get_team_stat_multiplier() -> float:
	# 每名存活拼音角色让伤害卡效果提高 20%。
	return 1.0 + float(get_pinyin_passive_count()) * 0.20


func get_wrong_answer_bonus_chance() -> float:
	# 每名存活词汇角色提供 25% 错题补偿概率，最高不超过 100%。
	return clampf(float(get_vocabulary_passive_count()) * 0.25, 0.0, 1.0)


func get_ap_growth_bonus() -> float:
	# 每名存活文化角色为每次 AP 增长额外提供 0.25。
	return float(get_culture_passive_count()) * 0.25


func add_ap(amount: float) -> void:
	ap = minf(5.0, ap + maxf(amount, 0.0))


func clear_ap() -> void:
	ap = 0.0


func add_new_toefl(amount: float) -> void:
	new_toefl = minf(6.0, new_toefl + maxf(amount, 0.0))


func spend_new_toefl(amount: float) -> bool:
	if new_toefl + 0.001 < amount:
		return false
	new_toefl = maxf(0.0, new_toefl - amount)
	return true


func push_log(message: String) -> void:
	battle_log.append(message)
	if battle_log.size() > 40:
		battle_log.pop_front()


func clear_pending_action() -> void:
	# 结算完成后整体清理，避免下一次行动复用旧目标或旧题目。
	selected_character = null
	selected_ally = null
	selected_enemy = null
	pending_card = null
	pending_question = null
	pending_difficulty = "easy"
