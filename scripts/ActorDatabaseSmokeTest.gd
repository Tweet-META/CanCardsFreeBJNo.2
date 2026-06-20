extends SceneTree


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
	assert(budding.max_hp == 110)
	assert(budding.defense == 4)
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
	assert(lawilim.portrait_path == "res://images/Lawilim.png")


func _test_enemies() -> void:
	var team: Array[EnemyData] = EnemyDatabase.create_default_team()
	assert(team.size() == 3)

	var tone_blob: EnemyData = team[0]
	assert(tone_blob.id == "tone_blob")
	assert(tone_blob.attribute == LearningAttribute.PINYIN)
	assert(tone_blob.max_hp == 70)
	assert(tone_blob.attack == 11)
	assert(tone_blob.defense == 1)

	var festival_mask: EnemyData = EnemyDatabase.create_enemy("festival_mask")
	assert(festival_mask != null)
	assert(festival_mask.display_name == "ENEMY_FESTIVAL_MASK")
	assert(festival_mask.attribute == LearningAttribute.CULTURE)
	assert(festival_mask.max_hp == 90)
	assert(is_equal_approx(festival_mask.toefl_reward, 1.5))
