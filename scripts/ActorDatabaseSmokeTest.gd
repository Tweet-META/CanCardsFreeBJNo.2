extends SceneTree
## 验证 characters.json、enemies.json、默认阵容与专属牌组映射。


func _init() -> void:
	CardDatabase.reload()
	CharacterDatabase.reload()
	EnemyDatabase.reload()

	_test_characters()
	_test_enemies()
	quit()


func _test_characters() -> void:
	var team: Array[CharacterData] = CharacterDatabase.create_default_team()
	assert(team.size() == 3)

	var budding: CharacterData = team[0]
	assert(budding.id == "budding")
	assert(budding.display_name == "CHARACTER_BUDDING")
	assert(budding.attribute == LearningAttribute.CULTURE)
	assert(budding.description == "CHARACTER_BUDDING_DESCRIPTION")
	assert(budding.max_hp == 110)
	assert(budding.cards.size() == 3)
	assert(budding.cards[0].id == "budding_attack")

	var rabbit: CharacterData = team[1]
	assert(rabbit.id == "tiancaitu")
	assert(rabbit.attribute == LearningAttribute.PINYIN)
	assert(rabbit.max_hp == 95)
	assert(rabbit.cards[2].id == "rabbit_skill")

	var lawilim: CharacterData = CharacterDatabase.create_character("lawilim")
	assert(lawilim != null)
	assert(lawilim.attribute == LearningAttribute.VOCABULARY)
	assert(lawilim.portrait_path == "res://assets/characters/Lawilim.png")


func _test_enemies() -> void:
	var team: Array[EnemyData] = EnemyDatabase.create_default_team()
	assert(team.size() == 3)

	var pinyin_bun: EnemyData = team[0]
	assert(pinyin_bun.id == "pinyin_bun")
	assert(pinyin_bun.display_name == "ENEMY_PINYIN_BUN")
	assert(pinyin_bun.attribute == LearningAttribute.PINYIN)
	assert(pinyin_bun.prototype == EnemyData.PROTOTYPE_BUN)
	assert(pinyin_bun.description == "ENEMY_PINYIN_BUN_DESCRIPTION")
	assert(pinyin_bun.max_hp == 70)
	assert(pinyin_bun.attack == 11)

	var vocab_slime: EnemyData = team[1]
	assert(vocab_slime.id == "vocab_slime")
	assert(vocab_slime.display_name == "ENEMY_VOCAB_SLIME")
	assert(vocab_slime.prototype == EnemyData.PROTOTYPE_SLIME)
	assert(vocab_slime.attack == 0)
	assert(vocab_slime.ability_power == 8)
	assert(vocab_slime.portrait_path == "res://assets/enemies/vocab_slime.png")

	var culture_mask: EnemyData = EnemyDatabase.create_enemy("culture_mask")
	assert(culture_mask != null)
	assert(culture_mask.display_name == "ENEMY_CULTURE_MASK")
	assert(culture_mask.attribute == LearningAttribute.CULTURE)
	assert(culture_mask.prototype == EnemyData.PROTOTYPE_MASK)
	assert(culture_mask.max_hp == 90)
	assert(is_equal_approx(culture_mask.toefl_reward, 1.5))

	var combination_ids: Array[String] = [
		"pinyin_bun", "vocab_bun", "culture_bun",
		"pinyin_slime", "vocab_slime", "culture_slime",
		"pinyin_mask", "vocab_mask", "culture_mask"
	]
	for enemy_id: String in combination_ids:
		var enemy: EnemyData = EnemyDatabase.create_enemy(enemy_id)
		assert(enemy != null)
		assert(ResourceLoader.exists(enemy.portrait_path))
