extends SceneTree
## 验证荆轲匕首先按当前生命值计算动态基础伤害，再应用攻击增益与目标易伤。


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var manager: BattleManager = BattleManager.new()
	root.add_child(manager)
	await process_frame

	var actor: CharacterData = manager.state.player_team[0]
	var target: EnemyData = manager.state.enemy_team[2]
	var dagger: CardData = CardDatabase.create_card("dagger_of_jingke")
	assert(dagger != null)
	assert(target.attribute == actor.attribute)

	target.current_hp = 90
	var vulnerable: StatusEffectData = EffectDatabase.create_effect(
		"vulnerable",
		0.20,
		2,
		"test_source",
		"CARD_BUDDING_ATTACK"
	)
	target.apply_status_effect(vulnerable)

	var dynamic_base_damage: int = roundi(float(target.current_hp) * 0.30)
	assert(dynamic_base_damage == 27)
	var damage_after_actor_bonuses: int = manager._calculate_damage(actor, target, dynamic_base_damage, 0.0)
	var expected_health_damage: int = roundi(float(damage_after_actor_bonuses) * 1.20)
	var hp_before: int = target.current_hp

	manager.state.selected_character = actor
	manager.state.selected_enemy = target
	manager.state.pending_card = dagger
	manager._apply_card_effect(false, true)

	assert(hp_before - target.current_hp == expected_health_damage)
	assert(manager.state.battle_log[-1].contains(str(hp_before)))
	assert(manager.state.battle_log[-1].contains(str(dynamic_base_damage)))
	assert(manager.state.battle_log[-1].contains(str(expected_health_damage)))
	quit()
