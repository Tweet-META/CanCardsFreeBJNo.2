extends SceneTree
## 验证易伤先于伤害生效、持续两个玩家回合，并在再次施加时刷新而不叠层。


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var manager: BattleManager = BattleManager.new()
	root.add_child(manager)
	await process_frame

	var budding: CharacterData = manager.state.player_team[0]
	var target: EnemyData = manager.state.enemy_team[0]
	var budding_attack: CardData = budding.cards[0]
	assert(budding_attack.effect_id == "attack_single_apply_effect")
	assert(budding_attack.status_effect_id == "vulnerable")
	var calculated_damage: int = manager._calculate_damage(budding, target, budding_attack.base_damage, 0.0)
	var expected_damage: int = roundi(float(calculated_damage) * 1.20)
	var hp_before: int = target.current_hp
	manager.state.selected_character = budding
	manager.state.selected_enemy = target
	manager.state.pending_card = budding_attack
	manager.state.pending_difficulty = "easy"
	manager._apply_card_effect(false, false)
	assert(target.get_status_effect("vulnerable") != null)
	assert(hp_before - target.current_hp == expected_damage)

	var enemy: EnemyData = EnemyDatabase.create_enemy("culture_mask")
	assert(enemy != null)
	enemy.setup_runtime()

	var vulnerable: StatusEffectData = EffectDatabase.create_effect(
		"vulnerable",
		0.20,
		2,
		"budding::budding_attack",
		"CARD_BUDDING_ATTACK"
	)
	assert(vulnerable != null)
	enemy.apply_status_effect(vulnerable)
	assert(enemy.active_effects.size() == 1)
	assert(enemy.take_damage(24) == 29)

	var standee_scene: PackedScene = load("res://scenes/ui/EnemyStandee.tscn") as PackedScene
	var standee: EnemyStandee = standee_scene.instantiate() as EnemyStandee
	root.add_child(standee)
	standee.setup(enemy, 0, false, false)
	assert(standee.effect_container.get_child_count() == 1)
	var displayed_icon: StatusEffectIcon = standee.effect_container.get_child(0) as StatusEffectIcon
	assert(displayed_icon.icon.texture != null)
	assert(displayed_icon.tooltip_text.contains(tr("CARD_BUDDING_ATTACK")))
	assert(displayed_icon.tooltip_text.contains("20%"))
	assert(not displayed_icon.tooltip_text.contains(tr("CHARACTER_BUDDING")))

	enemy.advance_status_effect_turns()
	assert(enemy.get_status_effect("vulnerable").remaining_turns == 1)

	var refreshed: StatusEffectData = EffectDatabase.create_effect(
		"vulnerable",
		0.20,
		2,
		"budding::budding_attack",
		"CARD_BUDDING_ATTACK"
	)
	enemy.apply_status_effect(refreshed)
	assert(enemy.active_effects.size() == 1)
	assert(enemy.get_status_effect("vulnerable").remaining_turns == 2)

	var other_source: StatusEffectData = EffectDatabase.create_effect("vulnerable", 0.20, 2, "future_actor", "Future Actor")
	enemy.apply_status_effect(other_source)
	assert(enemy.active_effects.size() == 2)
	assert(is_equal_approx(enemy.get_incoming_damage_multiplier(), 1.44))

	enemy.advance_status_effect_turns()
	assert(enemy.get_status_effect("vulnerable") != null)
	enemy.advance_status_effect_turns()
	assert(enemy.get_status_effect("vulnerable") == null)

	quit()
