extends SceneTree
## 覆盖开局、通用卡、答题攻击、自动换回合、技能困难题与 AP 清零的主流程。


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	# 实例化真实 BattleScene，避免只测试孤立数据类而漏掉信号接线问题。
	var file := FileAccess.open("res://smoke_test_result.txt", FileAccess.WRITE)
	if file != null:
		file.store_line("SmokeTest started")

	var packed_scene: PackedScene = load("res://scenes/BattleScene.tscn")
	assert(packed_scene != null)
	var scene := packed_scene.instantiate()
	root.add_child(scene)
	await process_frame

	var manager: BattleManager = scene.get_node("BattleManager")
	assert(manager.state.player_team[0].max_hp == 132)
	assert(manager.state.player_team[0].current_hp == 132)
	assert(manager.state.player_team[1].max_hp == 114)
	assert(manager.state.player_team[1].current_hp == 114)
	assert(manager.state.player_team[2].max_hp == 120)
	assert(manager.state.player_team[2].current_hp == 120)

	manager.request_use_card(0, -1000, -1, -1, "easy")
	assert(manager.state.player_team[0].has_acted)
	assert(manager.state.ap > 0.0)

	manager.request_use_card(1, 0, 0, -1, "easy")
	assert(manager.state.phase == BattleState.Phase.QUESTION)
	manager.submit_answer(manager.state.pending_question.correct_index)
	assert(manager.state.player_team[1].has_acted)
	assert(manager.state.enemy_team[0].current_hp == 33)

	manager.request_use_card(2, -1000, -1, -1, "easy")
	assert(manager.state.turn_count >= 2 or manager.state.phase == BattleState.Phase.VICTORY)

	manager.retry_battle()
	manager.state.ap = 5.0
	manager.request_use_card(0, 2, -1, -1, "easy")
	assert(manager.state.phase == BattleState.Phase.QUESTION)
	assert(manager.state.pending_difficulty == "hard")
	manager.submit_answer(manager.state.pending_question.correct_index)
	assert(manager.state.player_team[0].has_acted)
	assert(is_zero_approx(manager.state.ap))

	if file != null:
		file.store_line("SmokeTest passed")
		file.close()
	quit()
