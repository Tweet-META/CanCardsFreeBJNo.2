extends SceneTree
## 验证攻击/防御卡答错仍获基础 AP，答对再叠加难度奖励。


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var manager: BattleManager = BattleManager.new()
	root.add_child(manager)
	await process_frame

	# 暂停词汇被动，保证答错不会随机触发难度奖励。
	manager.state.player_team[2].current_hp = 0
	manager.request_use_card(0, 0, 0, -1)
	assert(manager.state.phase == BattleState.Phase.DIFFICULTY_SELECTION)
	manager.select_question_difficulty("medium")
	var wrong_index: int = (manager.state.pending_question.correct_index + 1) % manager.state.pending_question.options.size()
	manager.submit_answer(wrong_index)
	assert(is_equal_approx(manager.state.ap, 0.75))

	manager.retry_battle()
	manager.state.player_team[2].current_hp = 0
	manager.request_use_card(0, 1, -1, 0)
	assert(manager.state.phase == BattleState.Phase.DIFFICULTY_SELECTION)
	manager.select_question_difficulty("hard")
	manager.submit_answer(manager.state.pending_question.correct_index)
	assert(is_equal_approx(manager.state.ap, 1.75))

	quit()
