extends SceneTree
## 验证 cards.json 映射、自动通用牌池、重复抽取和关键卡牌数值。


func _init() -> void:
	CardDatabase.reload()

	var team: Array[CharacterData] = GameDataFactory.create_player_team()
	assert(team.size() == 3)
	assert(team[0].cards.size() == 3)
	assert(team[1].cards.size() == 3)
	assert(team[2].cards.size() == 3)

	var budding_attack: CardData = team[0].cards[0]
	assert(budding_attack.id == "budding_attack")
	assert(budding_attack.base_damage == 24)
	assert(is_equal_approx(budding_attack.base_ap_gain, 0.5))
	assert(budding_attack.effect_id == "attack_single")
	assert(budding_attack.required_attribute == "文化")

	var rabbit_skill: CardData = team[1].cards[2]
	assert(rabbit_skill.base_damage == 46)
	assert(rabbit_skill.target_type == CardData.TargetType.SINGLE_ENEMY)
	assert(rabbit_skill.effect_id == "skill_attack_single")
	assert(rabbit_skill.get_question_difficulty("easy") == "hard")

	var lawilim_skill: CardData = team[2].cards[2]
	assert(lawilim_skill.base_damage == 28)
	assert(lawilim_skill.target_type == CardData.TargetType.ALL_ENEMIES)
	assert(lawilim_skill.effect_id == "skill_attack_all")

	var general_pool_ids: Array[String] = CardDatabase.get_general_pool_ids()
	assert(general_pool_ids.size() == 9)
	assert(general_pool_ids.has("general_ap_1"))
	assert(general_pool_ids.has("shop_general_ap_big"))
	assert(not general_pool_ids.has("budding_attack"))
	for card_id: String in general_pool_ids:
		var pool_card: CardData = CardDatabase.create_card(card_id)
		assert(pool_card != null)
		assert(pool_card.is_general())

	var starting_rng: RandomNumberGenerator = RandomNumberGenerator.new()
	starting_rng.seed = 12345
	var starting_cards: Array[CardData] = GameDataFactory.create_starting_general_cards(starting_rng)
	assert(starting_cards.size() == 3)
	for card: CardData in starting_cards:
		assert(card.effect_id == "gain_team_ap")
		assert(general_pool_ids.has(card.id))
		assert(card.get_question_difficulty("medium") == "medium")

	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 12345
	var offers: Array[CardData] = GameDataFactory.create_shop_general_offers(rng, 4)
	assert(offers.size() == 4)
	for card: CardData in offers:
		assert(card.is_general())
		assert(card.effect_id == "gain_team_ap")
		assert(card.shop_price > 0.0)

	assert(_can_draw_duplicates(3, true))
	assert(_can_draw_duplicates(4, false))

	quit()


func _can_draw_duplicates(count: int, starting_hand: bool) -> bool:
	# 扫描一组固定种子，证明抽取是有放回而不是仅凭某一次随机结果。
	for seed_value in 100:
		var rng: RandomNumberGenerator = RandomNumberGenerator.new()
		rng.seed = seed_value
		var cards: Array[CardData]
		if starting_hand:
			cards = GameDataFactory.create_starting_general_cards(rng)
		else:
			cards = GameDataFactory.create_shop_general_offers(rng, count)
		var unique_ids: Dictionary = {}
		for card: CardData in cards:
			unique_ids[card.id] = true
		if unique_ids.size() < cards.size():
			return true
	return false
