extends RefCounted
## Defines the BattleState script.
class_name BattleState

const MAX_NEW_TOEFL: float = 120.0

enum Phase {
	SETUP,
	PLAYER_TURN,
	DIFFICULTY_SELECTION,
	QUESTION,
	ANSWER_RESULT,
	ACTION_RESOLUTION,
	ENEMY_TURN,
	VICTORY,
	DEFEAT
}

var phase: Phase = Phase.SETUP
var turn_count: int = 0
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
var pending_answer_correct: bool = false
var pending_answer_bonus_triggered: bool = false
var ap: float = 0.0
var new_toefl: float = 0.0
var team_general_cards: Array[CardData] = []
var shop_offer_cards: Array[CardData] = []
var battle_log: Array[String] = []
var learning_goal: LearningGoalData
var general_cards_enabled: bool = false
var tutorial: TutorialData
var tutorial_steps_seen: Dictionary = {}
var tutorial_log_unread: bool = false
var currency_settled: bool = false


## Initializes a battle with one optional goal that remains active for the full battle.
func setup(players: Array[CharacterData], enemies: Array[EnemyData], level: LevelData, goal: LearningGoalData, rng: RandomNumberGenerator = null) -> void:
	player_team = players
	enemy_team = enemies
	learning_goal = goal
	general_cards_enabled = level.general_cards_enabled
	tutorial = TutorialDatabase.create_for_level(level) if SaveManager.needs_first_tutorial() else null
	tutorial_steps_seen.clear()
	tutorial_log_unread = false
	battle_background = level.battle_background
	current_wave = 1
	total_waves = maxi(1, level.waves.size())
	phase = Phase.SETUP
	turn_count = 0
	ap = 0.0
	new_toefl = 0.0
	currency_settled = false
	team_general_cards.clear()
	if general_cards_enabled:
		team_general_cards = GameDataFactory.create_starting_general_cards(rng)
	shop_offer_cards.clear()
	battle_log.clear()

	var max_hp_multiplier: float = get_team_stat_multiplier()
	for character: CharacterData in player_team:
		character.setup_runtime(max_hp_multiplier)
	for enemy: EnemyData in enemy_team:
		enemy.setup_runtime()


func replace_enemy_wave(enemies: Array[EnemyData], wave_number: int) -> void:
	enemy_team = enemies
	current_wave = clampi(wave_number, 1, total_waves)
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
	pending_answer_correct = false
	pending_answer_bonus_triggered = false

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


## Returns the selected goal's team HP and card-damage multiplier.
func get_team_stat_multiplier() -> float:
	return learning_goal.team_stat_multiplier if learning_goal != null else 1.0


## Returns the selected goal's wrong-answer compensation chance.
func get_wrong_answer_bonus_chance() -> float:
	return clampf(learning_goal.wrong_answer_bonus_chance, 0.0, 1.0) if learning_goal != null else 0.0


## Returns the selected goal's flat bonus added to AP gains.
func get_ap_growth_bonus() -> float:
	return learning_goal.ap_growth_bonus if learning_goal != null else 0.0


func add_ap(amount: float) -> void:
	ap = minf(5.0, ap + maxf(amount, 0.0))


func clear_ap() -> void:
	ap = 0.0


## Keeps battle currency within its 120 New TOEFL cap.
func add_new_toefl(amount: float) -> void:
	new_toefl = minf(MAX_NEW_TOEFL, new_toefl + maxf(amount, 0.0))


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
	pending_answer_correct = false
	pending_answer_bonus_triggered = false
