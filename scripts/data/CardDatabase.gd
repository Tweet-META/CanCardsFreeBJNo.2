extends RefCounted
## Defines the CardDatabase script.
class_name CardDatabase

const DATA_PATH: String = "res://data/cards.json"

static var _loaded: bool = false
static var _definitions: Dictionary = {}


## Creates card runtime data including its separate permanent unlock price.
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
	card.art_path = str(raw.get("art_path", ""))
	card.shop_price = float(raw.get("shop_price", 0.0))
	card.unlock_price = maxf(0.0, float(raw.get("unlock_price", card.shop_price)))
	card.summary = str(raw.get("summary", ""))
	card.hit_count = maxi(1, int(raw.get("hit_count", 1)))
	card.ap_switch_threshold = float(raw.get("ap_switch_threshold", 2.5))
	card.extra_target_count = maxi(0, int(raw.get("extra_target_count", 0)))
	for value: Variant in raw.get("chain_damage_sequence", []) as Array:
		card.chain_damage_sequence.append(maxi(0, int(value)))
	for value: Variant in raw.get("random_hit_effects", []) as Array:
		var item: Dictionary = value as Dictionary
		var option: CardStatusOption = CardStatusOption.new()
		option.effect_id = str(item.get("effect_id", ""))
		option.value = float(item.get("value", 0.0))
		option.duration = maxi(1, int(item.get("duration", 1)))
		card.random_hit_effects.append(option)
	return card


static func create_cards(card_ids: Array[String]) -> Array[CardData]:
	var cards: Array[CardData] = []
	for card_id: String in card_ids:
		var card: CardData = create_card(card_id)
		if card != null:
			cards.append(card)
	return cards


## Restricts every normal random draw to permanently unlocked general cards.
static func get_general_pool_ids() -> Array[String]:
	_ensure_loaded()
	var general_ids: Array[String] = []
	for card_id_value: Variant in _definitions:
		var card_id: String = str(card_id_value)
		var raw_value: Variant = _definitions[card_id_value]
		if not raw_value is Dictionary:
			continue
		var raw: Dictionary = raw_value as Dictionary
		if str(raw.get("type", "")) == "general" and bool(raw.get("available_in_pool", true)) and SaveManager.is_general_card_unlocked(card_id):
			general_ids.append(card_id)
	return general_ids


## Lists normal general cards for the permanent unlock stall, including locked additions.
static func create_vendor_cards() -> Array[CardData]:
	_ensure_loaded()
	var cards: Array[CardData] = []
	for key: Variant in _definitions:
		var raw: Dictionary = _definitions[key] as Dictionary
		if str(raw.get("type", "")) == "general" and bool(raw.get("available_in_pool", true)):
			cards.append(create_card(str(key)))
	return cards


## Supplies the explicit starter unlock list without recursively querying the save.
static func get_initial_general_card_ids() -> Array[String]:
	_ensure_loaded()
	var ids: Array[String] = []
	for key: Variant in _definitions:
		var raw: Dictionary = _definitions[key] as Dictionary
		if str(raw.get("type", "")) == "general" and bool(raw.get("available_in_pool", true)) and bool(raw.get("initially_unlocked", false)):
			ids.append(str(key))
	return ids


static func reload() -> void:
	_loaded = false
	_definitions.clear()
	_ensure_loaded()


static func _ensure_loaded() -> void:
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

	var root_data: Dictionary = parsed as Dictionary
	var cards_value: Variant = root_data.get("cards")
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
