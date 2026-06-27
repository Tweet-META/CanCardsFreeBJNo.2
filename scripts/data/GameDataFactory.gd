extends RefCounted
## 面向战斗层的数据组装门面；具体数值全部来自各 JSON 数据库。
class_name GameDataFactory


## 创建默认我方队伍。
static func create_player_team() -> Array[CharacterData]:
	var selected_character_ids: Array[String] = LevelDatabase.get_active_player_ids()
	if not selected_character_ids.is_empty():
		return CharacterDatabase.create_team(selected_character_ids)
	return CharacterDatabase.create_default_team()


## 根据关卡波次配置生成本波敌人。
static func create_level_wave(level: LevelData, wave_index: int, rng: RandomNumberGenerator) -> Array[EnemyData]:
	# 每个 monster 位置独立随机选择一个候选怪物，最多生成八只。
	var enemies: Array[EnemyData] = []
	if level == null or wave_index < 0 or wave_index >= level.waves.size():
		return enemies
	for slot: MonsterSlotData in level.waves[wave_index].monster_slots:
		if enemies.size() >= 8 or slot.candidate_enemy_ids.is_empty():
			break
		var enemy_id: String = slot.candidate_enemy_ids[rng.randi_range(0, slot.candidate_enemy_ids.size() - 1)]
		var enemy: EnemyData = EnemyDatabase.create_enemy(enemy_id)
		if enemy != null:
			enemies.append(enemy)
	return enemies


## 创建开发者工具使用的文化面具敌人。
static func create_culture_mask_enemy() -> EnemyData:
	return EnemyDatabase.create_enemy("culture_mask")


## 创建开局三张团队通用卡。
static func create_starting_general_cards(rng: RandomNumberGenerator = null) -> Array[CardData]:
	# 开局从完整通用池有放回抽取三张，因此允许重复。
	return _draw_general_cards(_get_rng(rng), 3)


## 创建击败敌人时掉落的一张团队通用卡。
static func create_enemy_drop_general_card(rng: RandomNumberGenerator) -> CardData:
	# 每名敌人被击败时从完整通用池有放回抽取一张。
	var cards: Array[CardData] = _draw_general_cards(rng, 1)
	return cards[0] if not cards.is_empty() else null


## 创建开发者工具使用的孔子药水卡。
static func create_potion_of_confucius() -> CardData:
	return CardDatabase.create_card("potion_of_confucius")


## 创建隐藏彩蛋卡六七。
static func create_six_seven() -> CardData:
	return CardDatabase.create_card("six_seven")


## 创建商店随机展示的通用卡列表。
static func create_shop_general_offers(rng: RandomNumberGenerator, count: int = 4) -> Array[CardData]:
	# 商店与开局共用同一通用池，也采用有放回抽取。
	return _draw_general_cards(rng, count)


## 从完整通用池有放回抽取指定数量的卡牌。
static func _draw_general_cards(rng: RandomNumberGenerator, count: int) -> Array[CardData]:
	var pool_ids: Array[String] = CardDatabase.get_general_pool_ids()
	var offers: Array[CardData] = []
	if pool_ids.is_empty():
		return offers
	for _i in count:
		var card_id: String = pool_ids[rng.randi_range(0, pool_ids.size() - 1)]
		var card: CardData = CardDatabase.create_card(card_id)
		if card != null:
			offers.append(card)
	return offers


## 没有外部随机数发生器时创建一个临时随机数发生器。
static func _get_rng(rng: RandomNumberGenerator) -> RandomNumberGenerator:
	if rng != null:
		return rng
	var generated_rng: RandomNumberGenerator = RandomNumberGenerator.new()
	generated_rng.randomize()
	return generated_rng
