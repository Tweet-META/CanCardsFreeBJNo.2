extends RefCounted
## Collects resources referenced indirectly by level and character JSON.
class_name LevelResourceManifest


## Includes all wave candidates without consuming the battle random generator.
static func collect(level: LevelData) -> PackedStringArray:
	var paths: Dictionary[String, bool] = {}
	_add(paths, level.scene_path)
	_add(paths, level.battle_background)
	for character: CharacterData in GameDataFactory.create_player_team():
		_add(paths, character.battle_animation_path)
		_add(paths, character.portrait_path)
		for card: CardData in character.cards:
			_add_card(paths, card)
	for wave: LevelWaveData in level.waves:
		for slot: MonsterSlotData in wave.monster_slots:
			for enemy_id: String in slot.candidate_enemy_ids:
				var enemy: EnemyData = EnemyDatabase.create_enemy(enemy_id)
				if enemy != null:
					_add(paths, enemy.portrait_path)
	if level.general_cards_enabled:
		for card_id: String in CardDatabase.get_general_pool_ids():
			_add_card(paths, CardDatabase.create_card(card_id))
	return PackedStringArray(paths.keys())


## Preloads card art and reusable effect icons referenced by each card.
static func _add_card(paths: Dictionary[String, bool], card: CardData) -> void:
	if card == null:
		return
	_add(paths, card.art_path)
	for effect_id: String in [card.status_effect_id, card.secondary_status_effect_id]:
		if effect_id.is_empty():
			continue
		var effect: StatusEffectData = EffectDatabase.create_effect(effect_id, 0.0, 1)
		if effect != null:
			_add(paths, effect.icon_path)


## Deduplicates nonempty paths while preserving discovery order.
static func _add(paths: Dictionary[String, bool], path: String) -> void:
	if not path.is_empty():
		paths[path] = true
