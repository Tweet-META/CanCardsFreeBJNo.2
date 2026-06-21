extends RefCounted
## 从 cards.json 延迟加载卡牌定义，并为每次请求创建独立 CardData 实例。
class_name CardDatabase

const DATA_PATH: String = "res://data/cards.json"

static var _loaded: bool = false
# 缓存原始 Dictionary 而不是 CardData，避免不同战斗共享可变 Resource 状态。
static var _root_data: Dictionary = {}
static var _definitions: Dictionary = {}


static func create_card(card_id: String) -> CardData:
	_ensure_loaded()
	var raw_value: Variant = _definitions.get(card_id)
	if not raw_value is Dictionary:
		push_error("CardDatabase: unknown card id '%s'." % card_id)
		return null

	var raw: Dictionary = raw_value as Dictionary
	var card: CardData = CardData.new()
	card.id = str(raw.get("id", ""))
	card.display_name = str(raw.get("display_name", ""))
	card.description = str(raw.get("description", ""))
	card.owner_id = str(raw.get("owner_id", ""))
	card.card_type = _card_type_from_string(str(raw.get("type", "attack")))
	card.target_type = _target_type_from_string(str(raw.get("target", "single_enemy")))
	card.required_attribute = LearningAttribute.from_id(str(raw.get("attribute", "none")))
	card.requires_question = bool(raw.get("requires_question", true))
	card.base_damage = int(raw.get("base_damage", 0))
	card.base_block = float(raw.get("base_block", 0.0))
	card.base_ap_gain = float(raw.get("base_ap_gain", 0.0))
	card.skill_ap_cost = float(raw.get("skill_ap_cost", 5.0))
	card.effect_id = str(raw.get("effect_id", ""))
	card.status_effect_id = str(raw.get("status_effect_id", ""))
	card.status_effect_value = float(raw.get("status_effect_value", 0.0))
	card.status_effect_duration = int(raw.get("status_effect_duration", 0))
	card.status_effect_delay = int(raw.get("status_effect_delay", 0))
	card.secondary_status_effect_id = str(raw.get("secondary_status_effect_id", ""))
	card.secondary_status_effect_value = float(raw.get("secondary_status_effect_value", 0.0))
	card.secondary_status_effect_duration = int(raw.get("secondary_status_effect_duration", 0))
	card.secondary_status_effect_delay = int(raw.get("secondary_status_effect_delay", 0))
	card.current_hp_damage_ratio = float(raw.get("current_hp_damage_ratio", 0.0))
	card.max_hp_heal_ratio = float(raw.get("max_hp_heal_ratio", 0.0))
	card.direct_hp_loss = int(raw.get("direct_hp_loss", 0))
	card.available_in_pool = bool(raw.get("available_in_pool", true))
	card.art_path = str(raw.get("art_path", ""))
	card.shop_price = float(raw.get("shop_price", 0.0))
	return card


static func create_cards(card_ids: Array[String]) -> Array[CardData]:
	var cards: Array[CardData] = []
	for card_id: String in card_ids:
		var card: CardData = create_card(card_id)
		if card != null:
			cards.append(card)
	return cards


static func get_general_pool_ids() -> Array[String]:
	# 所有 type=general 的卡牌自动进入开局与商店随机池。
	_ensure_loaded()
	var general_ids: Array[String] = []
	for card_id_value: Variant in _definitions:
		var card_id: String = str(card_id_value)
		var raw_value: Variant = _definitions[card_id_value]
		if not raw_value is Dictionary:
			continue
		var raw: Dictionary = raw_value as Dictionary
		if str(raw.get("type", "")) == "general" and bool(raw.get("available_in_pool", true)):
			general_ids.append(card_id)
	return general_ids


static func reload() -> void:
	# 主要供测试和编辑器热更新使用；正常游戏只加载一次 JSON。
	_loaded = false
	_root_data.clear()
	_definitions.clear()
	_ensure_loaded()


static func _ensure_loaded() -> void:
	# 首次访问时解析并按 ID 建立索引，后续创建卡牌无需重复读取磁盘。
	if _loaded:
		return
	_loaded = true

	var file: FileAccess = FileAccess.open(DATA_PATH, FileAccess.READ)
	if file == null:
		push_error("CardDatabase: could not open %s." % DATA_PATH)
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if not parsed is Dictionary:
		push_error("CardDatabase: %s must contain a JSON object." % DATA_PATH)
		return

	_root_data = parsed as Dictionary
	var cards_value: Variant = _root_data.get("cards")
	if not cards_value is Array:
		push_error("CardDatabase: cards must be an array.")
		return

	var raw_cards: Array = cards_value as Array
	for raw_value: Variant in raw_cards:
		if not raw_value is Dictionary:
			continue
		var raw: Dictionary = raw_value as Dictionary
		var card_id: String = str(raw.get("id", ""))
		if card_id.is_empty():
			push_error("CardDatabase: card definition is missing an id.")
			continue
		if _definitions.has(card_id):
			push_error("CardDatabase: duplicate card id '%s'." % card_id)
			continue
		_definitions[card_id] = raw


static func _to_string_array(value: Variant) -> Array[String]:
	var result: Array[String] = []
	if not value is Array:
		return result
	var values: Array = value as Array
	for item: Variant in values:
		result.append(str(item))
	return result


static func _card_type_from_string(value: String) -> CardData.CardType:
	match value:
		"attack":
			return CardData.CardType.ATTACK
		"defense":
			return CardData.CardType.DEFENSE
		"skill":
			return CardData.CardType.SKILL
		"general":
			return CardData.CardType.GENERAL
		_:
			push_error("CardDatabase: unknown card type '%s'." % value)
			return CardData.CardType.ATTACK


static func _target_type_from_string(value: String) -> CardData.TargetType:
	match value:
		"self":
			return CardData.TargetType.SELF
		"single_ally":
			return CardData.TargetType.SINGLE_ALLY
		"single_enemy":
			return CardData.TargetType.SINGLE_ENEMY
		"all_enemies":
			return CardData.TargetType.ALL_ENEMIES
		"all_allies":
			return CardData.TargetType.ALL_ALLIES
		_:
			push_error("CardDatabase: unknown target type '%s'." % value)
			return CardData.TargetType.SELF
