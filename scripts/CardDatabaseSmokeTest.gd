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
	assert(budding_attack.effect_id == "attack_single_apply_effect")
	assert(budding_attack.status_effect_id == "vulnerable")
	assert(is_equal_approx(budding_attack.status_effect_value, 0.20))
	assert(budding_attack.status_effect_duration == 2)
	assert(budding_attack.required_attribute == "文化")

	var rabbit_skill: CardData = team[1].cards[2]
	var rabbit_attack: CardData = team[1].cards[0]
	assert(rabbit_attack.base_damage == 26)
	assert(rabbit_attack.effect_id == "attack_primary_splash")
	assert(rabbit_skill.base_damage == 92)
	assert(rabbit_skill.target_type == CardData.TargetType.SINGLE_ENEMY)
	assert(rabbit_skill.effect_id == "skill_attack_single")
	assert(rabbit_skill.get_question_difficulty("easy") == "hard")

	var lawilim_skill: CardData = team[2].cards[2]
	assert(lawilim_skill.base_damage == 28)
	assert(lawilim_skill.target_type == CardData.TargetType.ALL_ENEMIES)
	assert(lawilim_skill.effect_id == "skill_attack_all")

	var general_pool_ids: Array[String] = CardDatabase.get_general_pool_ids()
	assert(general_pool_ids.size() == 8)
	assert(general_pool_ids.has("potion_of_confucius"))
	assert(general_pool_ids.has("dagger_of_jingke"))
	assert(general_pool_ids.has("impenetrable_shield"))
	assert(general_pool_ids.has("menghan_toxin"))
	assert(general_pool_ids.has("elixir_of_huatuo"))
	assert(general_pool_ids.has("gall_of_goujian"))
	assert(general_pool_ids.has("insight_of_paoding"))
	assert(general_pool_ids.has("smashed_cauldron"))
	assert(not general_pool_ids.has("six_seven"))
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
		assert(general_pool_ids.has(card.id))
		assert(card.get_question_difficulty("medium") == "medium")

	var drop_rng: RandomNumberGenerator = RandomNumberGenerator.new()
	drop_rng.seed = 54321
	var dropped_card: CardData = GameDataFactory.create_enemy_drop_general_card(drop_rng)
	assert(dropped_card != null)
	assert(dropped_card.is_general())
	assert(general_pool_ids.has(dropped_card.id))

	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 12345
	var offers: Array[CardData] = GameDataFactory.create_shop_general_offers(rng, 4)
	assert(offers.size() == 4)
	for card: CardData in offers:
		assert(card.is_general())
		assert(card.shop_price > 0.0)

	var potion: CardData = CardDatabase.create_card("potion_of_confucius")
	assert(potion.effect_id == "gain_team_ap")
	assert(is_equal_approx(potion.base_ap_gain, 2.5))
	assert(potion.art_path == "res://assets/cards/potion_of_confucius.png")

	var dagger: CardData = CardDatabase.create_card("dagger_of_jingke")
	assert(dagger.effect_id == "damage_current_hp_percent")
	assert(dagger.target_type == CardData.TargetType.SINGLE_ENEMY)
	assert(is_equal_approx(dagger.current_hp_damage_ratio, 0.30))
	assert(dagger.art_path == "res://assets/cards/dagger_of_jingke.png")

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
