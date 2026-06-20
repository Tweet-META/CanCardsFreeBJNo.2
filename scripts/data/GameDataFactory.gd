extends RefCounted
class_name GameDataFactory


static func create_player_team() -> Array[CharacterData]:
	return CharacterDatabase.create_default_team()


static func create_enemy_team() -> Array[EnemyData]:
	return EnemyDatabase.create_default_team()


static func create_festival_mask_enemy() -> EnemyData:
	return EnemyDatabase.create_enemy("festival_mask")


static func create_starting_general_cards(rng: RandomNumberGenerator = null) -> Array[CardData]:
	return _draw_general_cards(_get_rng(rng), 3)


static func create_general_encouragement_i() -> CardData:
	return CardDatabase.create_card("general_ap_1")


static func create_shop_general_offers(rng: RandomNumberGenerator, count: int = 4) -> Array[CardData]:
	return _draw_general_cards(rng, count)


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


static func _get_rng(rng: RandomNumberGenerator) -> RandomNumberGenerator:
	if rng != null:
		return rng
	var generated_rng: RandomNumberGenerator = RandomNumberGenerator.new()
	generated_rng.randomize()
	return generated_rng
