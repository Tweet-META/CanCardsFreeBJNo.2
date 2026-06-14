extends SceneTree


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var file := FileAccess.open("res://smoke_test_result.txt", FileAccess.WRITE)
	if file != null:
		file.store_line("SmokeTest started")

	var packed_scene: PackedScene = load("res://scenes/BattleScene.tscn")
	assert(packed_scene != null)
	var scene := packed_scene.instantiate()
	root.add_child(scene)
	await process_frame

	var manager: BattleManager = scene.get_node("BattleManager")
	manager.request_use_card(0, -1000, -1, -1, "easy")
	assert(manager.state.player_team[0].has_acted)
	assert(manager.state.ap > 0.0)

	manager.request_use_card(1, 0, 0, -1, "easy")
	assert(manager.state.phase == BattleState.Phase.QUESTION)
	manager.submit_answer(manager.state.pending_question.correct_index)
	assert(manager.state.player_team[1].has_acted)

	manager.request_use_card(2, -1000, -1, -1, "easy")
	assert(manager.state.turn_count >= 2 or manager.state.phase == BattleState.Phase.VICTORY)

	manager.retry_battle()
	manager.state.ap = 5.0
	manager.request_use_card(0, 2, -1, -1, "easy")
	assert(manager.state.phase == BattleState.Phase.QUESTION)
	manager.submit_answer(manager.state.pending_question.correct_index)
	assert(manager.state.player_team[0].has_acted)

	if file != null:
		file.store_line("SmokeTest passed")
		file.close()
	quit()
