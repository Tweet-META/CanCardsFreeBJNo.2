extends RefCounted
class_name GameDataFactory


static func create_player_team() -> Array[CharacterData]:
	var budding := _make_character("budding", "βudding", "文化", 110, 18, 4)
	budding.portrait_path = "res://images/βudding.png"
	budding.cards = [
		_make_card("budding_attack", "文化纸牌", "回答文化题，造成伤害。答对按难度提高伤害并获得 AP。", "budding", CardData.CardType.ATTACK, CardData.TargetType.SINGLE_ENEMY, "文化", true, "", 24, 0.0, 0.5, false),
		_make_card("budding_defense", "社团守护", "回答文化题，答对获得本回合减伤。", "budding", CardData.CardType.DEFENSE, CardData.TargetType.SELF, "文化", true, "", 0, 0.15, 0.5, false),
		_make_card("budding_skill", "清明春风", "AP 满时可用。回答困难文化题，对全体敌人造成伤害；答对额外提高伤害。", "budding", CardData.CardType.SKILL, CardData.TargetType.ALL_ENEMIES, "文化", true, "hard", 30, 0.0, 0.0, true)
	]
	budding.cards[0].art_path = "res://assets/cards/exclusive/budding_attack.png"
	budding.cards[1].art_path = "res://assets/cards/exclusive/budding_defense.png"
	budding.cards[2].art_path = "res://assets/cards/exclusive/budding_skill.png"

	var rabbit := _make_character("tiancaitu", "天才兔", "拼音", 95, 21, 3)
	rabbit.portrait_path = "res://images/天才兔.png"
	rabbit.cards = [
		_make_card("rabbit_attack", "拼音连击", "回答拼音题，造成伤害。答对按难度提高伤害并获得 AP。", "tiancaitu", CardData.CardType.ATTACK, CardData.TargetType.SINGLE_ENEMY, "拼音", true, "", 26, 0.0, 0.5, false),
		_make_card("rabbit_defense", "声调护盾", "回答拼音题，答对获得本回合减伤。", "tiancaitu", CardData.CardType.DEFENSE, CardData.TargetType.SELF, "拼音", true, "", 0, 0.12, 0.5, false),
		_make_card("rabbit_skill", "四声爆发", "AP 满时可用。回答困难拼音题，对单体敌人造成高伤害；答对额外提高伤害。", "tiancaitu", CardData.CardType.SKILL, CardData.TargetType.SINGLE_ENEMY, "拼音", true, "hard", 46, 0.0, 0.0, true)
	]
	rabbit.cards[0].art_path = "res://assets/cards/exclusive/rabbit_attack.png"
	rabbit.cards[1].art_path = "res://assets/cards/exclusive/rabbit_defense.png"
	rabbit.cards[2].art_path = "res://assets/cards/exclusive/rabbit_skill.png"

	var lawilim := _make_character("lawilim", "Lawilim", "词汇", 100, 20, 3)
	lawilim.portrait_path = "res://images/Lawilim.png"
	lawilim.cards = [
		_make_card("lawilim_attack", "词汇冲击", "回答词汇题，造成伤害。答对按难度提高伤害并获得 AP。", "lawilim", CardData.CardType.ATTACK, CardData.TargetType.SINGLE_ENEMY, "词汇", true, "", 25, 0.0, 0.5, false),
		_make_card("lawilim_defense", "释义屏障", "回答词汇题，答对获得本回合减伤。", "lawilim", CardData.CardType.DEFENSE, CardData.TargetType.SELF, "词汇", true, "", 0, 0.12, 0.5, false),
		_make_card("lawilim_skill", "词海回响", "AP 满时可用。回答困难词汇题，对全体敌人造成伤害；答对额外提高伤害。", "lawilim", CardData.CardType.SKILL, CardData.TargetType.ALL_ENEMIES, "词汇", true, "hard", 28, 0.0, 0.0, true)
	]
	lawilim.cards[0].art_path = "res://assets/cards/exclusive/lawilim_attack.png"
	lawilim.cards[1].art_path = "res://assets/cards/exclusive/lawilim_defense.png"
	lawilim.cards[2].art_path = "res://assets/cards/exclusive/lawilim_skill.png"

	return [budding, rabbit, lawilim]


static func create_enemy_team() -> Array[EnemyData]:
	return [
		_make_enemy("tone_blob", "声调团子", "拼音", 70, 11, 1, 1.0, "res://assets/enemies/tone_blob.png"),
		_make_enemy("word_slime", "词语史莱姆", "词汇", 80, 12, 2, 1.0, "res://assets/enemies/word_slime.png"),
		_make_enemy("festival_mask", "节日面具", "文化", 90, 13, 2, 1.5, "res://assets/enemies/festival_mask.png")
	]


static func create_starting_general_cards() -> Array[CardData]:
	return [
		_make_general_card("general_ap_1", "通用鼓励 I"),
		_make_general_card("general_ap_2", "通用鼓励 II"),
		_make_general_card("general_ap_3", "通用鼓励 III")
	]


static func create_shop_general_offers(rng: RandomNumberGenerator, count: int = 4) -> Array[CardData]:
	var pool: Array[CardData] = [
		_make_shop_general_card("shop_general_ap_small", "鼓励便签", "使用后获得 +1.0 AP。", 1.0, 0.5),
		_make_shop_general_card("shop_general_ap_focus", "专注贴纸", "使用后获得 +1.3 AP。", 1.3, 0.8),
		_make_shop_general_card("shop_general_ap_flash", "灵感糖果", "使用后获得 +1.5 AP。", 1.5, 1.0),
		_make_shop_general_card("shop_general_ap_burst", "速记药水", "使用后获得 +2.0 AP。", 2.0, 1.4),
		_make_shop_general_card("shop_general_ap_value", "社团加油", "使用后获得 +1.2 AP。", 1.2, 0.7),
		_make_shop_general_card("shop_general_ap_big", "满分冲刺", "使用后获得 +2.5 AP。", 2.5, 1.8)
	]
	var offers: Array[CardData] = []
	for i in count:
		var template: CardData = pool[rng.randi_range(0, pool.size() - 1)]
		offers.append(template.duplicate(true) as CardData)
	return offers


static func _make_character(id: String, display_name: String, attribute: String, hp: int, attack: int, defense: int) -> CharacterData:
	var character := CharacterData.new()
	character.id = id
	character.display_name = display_name
	character.attribute = attribute
	character.max_hp = hp
	character.attack = attack
	character.defense = defense
	return character


static func _make_enemy(id: String, display_name: String, attribute: String, hp: int, attack: int, defense: int, reward: float, portrait_path: String) -> EnemyData:
	var enemy := EnemyData.new()
	enemy.id = id
	enemy.display_name = display_name
	enemy.attribute = attribute
	enemy.max_hp = hp
	enemy.attack = attack
	enemy.defense = defense
	enemy.toefl_reward = reward
	enemy.portrait_path = portrait_path
	return enemy


static func _make_card(id: String, display_name: String, description: String, owner_id: String, card_type: CardData.CardType, target_type: CardData.TargetType, required_attribute: String, requires_question: bool, fixed_difficulty: String, base_damage: int, base_block: float, base_ap_gain: float, clears_ap_on_use: bool) -> CardData:
	var card := CardData.new()
	card.id = id
	card.display_name = display_name
	card.description = description
	card.owner_id = owner_id
	card.card_type = card_type
	card.target_type = target_type
	card.required_attribute = required_attribute
	card.requires_question = requires_question
	card.fixed_difficulty = fixed_difficulty
	card.base_damage = base_damage
	card.base_block = base_block
	card.base_ap_gain = base_ap_gain
	card.clears_ap_on_use = clears_ap_on_use
	card.art_path = _default_art_path_for_type(card_type)
	return card


static func _make_general_card(id: String, display_name: String) -> CardData:
	return _make_card(id, display_name, "无需答题，立刻获得 +1 AP。", "", CardData.CardType.GENERAL, CardData.TargetType.SELF, "", false, "", 0, 0.0, 1.0, false)


static func _make_shop_general_card(id: String, display_name: String, description: String, ap_gain: float, price: float) -> CardData:
	var card: CardData = _make_card(id, display_name, description, "", CardData.CardType.GENERAL, CardData.TargetType.SELF, "", false, "", 0, 0.0, ap_gain, false)
	card.shop_price = price
	return card


static func _default_art_path_for_type(card_type: CardData.CardType) -> String:
	match card_type:
		CardData.CardType.ATTACK:
			return "res://assets/cards/card_icon_attack.png"
		CardData.CardType.DEFENSE:
			return "res://assets/cards/card_icon_defense.png"
		CardData.CardType.SKILL:
			return "res://assets/cards/card_icon_skill.png"
		CardData.CardType.GENERAL:
			return "res://assets/cards/card_icon_general.png"
		_:
			return "res://assets/cards/card_icon_general.png"
