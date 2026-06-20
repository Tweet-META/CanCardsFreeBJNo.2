extends SceneTree
## 验证三种属性被动按属性而非角色 ID 统计，并支持同属性叠加。


func _init() -> void:
	_test_pinyin_stacking()
	_test_vocabulary_stacking()
	_test_culture_stacking()
	quit()


func _test_pinyin_stacking() -> void:
	# 生命按开战总人数计算，战斗中的伤害倍率按存活人数计算。
	var players: Array[CharacterData] = [
		_make_character("pinyin_one", BattleState.ATTRIBUTE_PINYIN, 100),
		_make_character("pinyin_two", BattleState.ATTRIBUTE_PINYIN, 80),
		_make_character("culture_one", BattleState.ATTRIBUTE_CULTURE, 120)
	]
	var state: BattleState = BattleState.new()
	state.setup(players, [], _seeded_rng())

	assert(state.get_attribute_count(BattleState.ATTRIBUTE_PINYIN) == 2)
	assert(state.get_pinyin_passive_count() == 2)
	assert(is_equal_approx(state.get_team_stat_multiplier(), 1.4))
	assert(players[0].max_hp == 140)
	assert(players[1].max_hp == 112)
	assert(players[2].max_hp == 168)

	players[1].current_hp = 0
	assert(state.get_pinyin_passive_count() == 1)
	assert(is_equal_approx(state.get_team_stat_multiplier(), 1.2))
	assert(state.get_attribute_count(BattleState.ATTRIBUTE_PINYIN, false) == 2)


func _test_vocabulary_stacking() -> void:
	var players: Array[CharacterData] = [
		_make_character("vocabulary_one", BattleState.ATTRIBUTE_VOCABULARY),
		_make_character("vocabulary_two", BattleState.ATTRIBUTE_VOCABULARY)
	]
	var state: BattleState = BattleState.new()
	state.setup(players, [], _seeded_rng())

	assert(state.get_vocabulary_passive_count() == 2)
	assert(is_equal_approx(state.get_wrong_answer_bonus_chance(), 0.5))

	players[0].current_hp = 0
	assert(is_equal_approx(state.get_wrong_answer_bonus_chance(), 0.25))


func _test_culture_stacking() -> void:
	var players: Array[CharacterData] = [
		_make_character("culture_one", BattleState.ATTRIBUTE_CULTURE),
		_make_character("culture_two", BattleState.ATTRIBUTE_CULTURE)
	]
	var state: BattleState = BattleState.new()
	state.setup(players, [], _seeded_rng())

	assert(state.get_culture_passive_count() == 2)
	assert(is_equal_approx(state.get_ap_growth_bonus(), 0.5))

	players[1].current_hp = 0
	assert(is_equal_approx(state.get_ap_growth_bonus(), 0.25))


func _make_character(id: String, attribute: String, max_hp: int = 100) -> CharacterData:
	var character: CharacterData = CharacterData.new()
	character.id = id
	character.attribute = attribute
	character.max_hp = max_hp
	return character


func _seeded_rng() -> RandomNumberGenerator:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 12345
	return rng
