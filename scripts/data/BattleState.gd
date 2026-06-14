extends RefCounted
class_name BattleState

enum Phase {
	SETUP,
	PLAYER_TURN,
	QUESTION,
	ENEMY_TURN,
	VICTORY,
	DEFEAT
}

const ATTRIBUTE_PINYIN: String = "拼音"
const ATTRIBUTE_VOCABULARY: String = "词汇"
const ATTRIBUTE_CULTURE: String = "文化"

var phase: Phase = Phase.SETUP
var turn_count: int = 0
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


func setup(players: Array[CharacterData], enemies: Array[EnemyData]) -> void:
	player_team = players
	enemy_team = enemies
	phase = Phase.SETUP
	turn_count = 0
	ap = 0.0
	new_toefl = 0.0
	team_general_cards = GameDataFactory.create_starting_general_cards()
	shop_offer_cards.clear()
	battle_log.clear()

	for character: CharacterData in player_team:
		character.setup_runtime()
	for enemy: EnemyData in enemy_team:
		enemy.setup_runtime()


func start_player_turn() -> void:
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
	return _count_alive_players_by_attribute(ATTRIBUTE_PINYIN)


func get_vocabulary_passive_count() -> int:
	return _count_alive_players_by_attribute(ATTRIBUTE_VOCABULARY)


func get_culture_passive_count() -> int:
	return _count_alive_players_by_attribute(ATTRIBUTE_CULTURE)


func get_team_stat_multiplier() -> float:
	return 1.0 + float(get_pinyin_passive_count()) * 0.20


func get_wrong_answer_bonus_chance() -> float:
	return clampf(float(get_vocabulary_passive_count()) * 0.25, 0.0, 1.0)


func get_ap_growth_bonus() -> float:
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
	selected_character = null
	selected_ally = null
	selected_enemy = null
	pending_card = null
	pending_question = null
	pending_difficulty = "easy"


func _count_alive_players_by_attribute(attribute: String) -> int:
	var count: int = 0
	for character: CharacterData in player_team:
		if character.is_alive() and character.attribute == attribute:
			count += 1
	return count
