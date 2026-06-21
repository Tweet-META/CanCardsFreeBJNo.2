extends SceneTree
## 验证多波生成、随机怪物位置、换波先手、资源保留与最终胜利。


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var manager: BattleManager = BattleManager.new()
	root.add_child(manager)
	await process_frame

	var stage: StageData = _make_three_wave_stage()
	manager.rng.seed = 20260621
	manager._start_battle_with_stage(stage)
	assert(manager.state.current_wave == 1)
	assert(manager.state.total_waves == 3)
	assert(manager.state.enemy_team.size() == 1)
	assert(manager.state.enemy_team[0].id in ["pinyin_bun", "culture_bun"])
	assert(manager.state.battle_background == "res://assets/ui/conversation_room.png")

	manager.state.ap = 2.5
	var card_count: int = manager.state.team_general_cards.size()
	manager.state.enemy_team[0].current_hp = 0
	assert(manager._check_battle_end())
	assert(manager.state.current_wave == 2)
	assert(manager.state.phase == BattleState.Phase.PLAYER_TURN)
	assert(manager.state.enemy_team.size() == 2)
	assert(is_equal_approx(manager.state.ap, 2.5))
	assert(manager.state.team_general_cards.size() == card_count)
	for character: CharacterData in manager.state.get_alive_players():
		assert(not character.has_acted)

	manager.state.enemy_team[0].current_hp = 0
	manager.state.enemy_team[1].current_hp = 0
	assert(manager._check_battle_end())
	assert(manager.state.current_wave == 3)
	assert(manager.state.phase == BattleState.Phase.PLAYER_TURN)
	assert(manager.state.enemy_team.size() == 1)

	manager.state.enemy_team[0].current_hp = 0
	assert(manager._check_battle_end())
	assert(manager.state.phase == BattleState.Phase.VICTORY)
	quit()


func _make_three_wave_stage() -> StageData:
	var stage: StageData = StageData.new()
	stage.id = "wave_test"
	stage.battle_background = "res://assets/ui/conversation_room.png"
	stage.waves = [
		_make_wave([["pinyin_bun", "culture_bun"]]),
		_make_wave([["vocab_slime"], ["culture_mask"]]),
		_make_wave([["pinyin_mask"]])
	]
	return stage


func _make_wave(slot_candidates: Array) -> StageWaveData:
	var wave: StageWaveData = StageWaveData.new()
	for candidate_value: Variant in slot_candidates:
		var slot: MonsterSlotData = MonsterSlotData.new()
		var candidates: Array[String] = []
		for enemy_id: Variant in candidate_value as Array:
			candidates.append(str(enemy_id))
		slot.candidate_enemy_ids = candidates
		wave.monster_slots.append(slot)
	return wave
