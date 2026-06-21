extends SceneTree
## 验证天才兔攻击牌对主目标使用 26 基础伤害，对其余目标使用 13 基础伤害。


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var manager: BattleManager = BattleManager.new()
	root.add_child(manager)
	await process_frame

	var rabbit: CharacterData = manager.state.player_team[1]
	var card: CardData = rabbit.cards[0]
	assert(card.effect_id == "attack_primary_splash")
	assert(manager.state.enemy_team.size() >= 3)

	var primary: EnemyData = manager.state.enemy_team[0]
	var secondary_a: EnemyData = manager.state.enemy_team[1]
	var secondary_b: EnemyData = manager.state.enemy_team[2]
	var primary_hp: int = primary.current_hp
	var secondary_a_hp: int = secondary_a.current_hp
	var secondary_b_hp: int = secondary_b.current_hp

	manager.state.selected_character = rabbit
	manager.state.selected_enemy = primary
	manager.state.pending_card = card
	manager.state.pending_difficulty = "easy"
	manager._apply_card_effect(false, false)

	var expected_primary: int = manager._calculate_damage(rabbit, primary, 26, 0.0)
	var expected_secondary_a: int = manager._calculate_damage(rabbit, secondary_a, 13, 0.0)
	var expected_secondary_b: int = manager._calculate_damage(rabbit, secondary_b, 13, 0.0)
	assert(primary_hp - primary.current_hp == expected_primary)
	assert(secondary_a_hp - secondary_a.current_hp == expected_secondary_a)
	assert(secondary_b_hp - secondary_b.current_hp == expected_secondary_b)

	quit()
