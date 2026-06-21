extends SceneTree
## 验证三种敌人原型的回合能力与敌方护盾结算。


func _init() -> void:
	var manager: BattleManager = BattleManager.new()
	root.add_child(manager)
	await process_frame

	_test_slime_support(manager)
	_test_bun_group_attack(manager)
	_test_mask_single_attack(manager)
	quit()


func _test_slime_support(manager: BattleManager) -> void:
	var slime: EnemyData = EnemyDatabase.create_enemy("vocab_slime")
	var ally: EnemyData = EnemyDatabase.create_enemy("culture_mask")
	slime.setup_runtime()
	ally.setup_runtime()
	manager.state.enemy_team = [slime, ally]

	manager._run_enemy_action(slime)
	assert(slime.current_shield == 8)
	assert(ally.current_shield == 8)

	var hp_before: int = ally.current_hp
	var dealt: int = ally.take_damage(8)
	assert(dealt == 0)
	assert(ally.current_hp == hp_before)
	assert(ally.current_shield == 0)


func _test_bun_group_attack(manager: BattleManager) -> void:
	var bun: EnemyData = EnemyDatabase.create_enemy("pinyin_bun")
	bun.setup_runtime()
	manager.state.enemy_team = [bun]
	for character: CharacterData in manager.state.player_team:
		character.current_hp = character.max_hp

	var hp_values: Array[int] = []
	for character: CharacterData in manager.state.player_team:
		hp_values.append(character.current_hp)
	manager._run_enemy_action(bun)
	for index: int in manager.state.player_team.size():
		assert(manager.state.player_team[index].current_hp < hp_values[index])


func _test_mask_single_attack(manager: BattleManager) -> void:
	var mask: EnemyData = EnemyDatabase.create_enemy("culture_mask")
	mask.setup_runtime()
	manager.state.enemy_team = [mask]
	for character: CharacterData in manager.state.player_team:
		character.current_hp = character.max_hp

	var total_hp_before: int = _total_player_hp(manager.state.player_team)
	manager._run_enemy_action(mask)
	var damaged_count: int = 0
	for character: CharacterData in manager.state.player_team:
		if character.current_hp < character.max_hp:
			damaged_count += 1
	assert(damaged_count == 1)
	assert(_total_player_hp(manager.state.player_team) < total_hp_before)

	var mixed_enemy: EnemyData = EnemyData.new()
	var disabled_ability: EnemyAbilityData = EnemyAbilityData.new()
	disabled_ability.id = "disabled"
	disabled_ability.weight = 0.0
	var selected_ability: EnemyAbilityData = EnemyAbilityData.new()
	selected_ability.id = "selected"
	selected_ability.weight = 1.0
	mixed_enemy.abilities = [disabled_ability, selected_ability]
	for _index in 20:
		assert(mixed_enemy.choose_ability(manager.rng) == selected_ability)


func _total_player_hp(team: Array[CharacterData]) -> int:
	var total: int = 0
	for character: CharacterData in team:
		total += character.current_hp
	return total
