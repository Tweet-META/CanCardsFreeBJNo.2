extends SceneTree
## 验证敌人首次死亡掉落一张通用卡，重复结算不会再次发放。


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var manager: BattleManager = BattleManager.new()
	root.add_child(manager)
	await process_frame

	var enemy: EnemyData = manager.state.enemy_team[0]
	var initial_card_count: int = manager.state.team_general_cards.size()
	var initial_toefl: float = manager.state.new_toefl
	enemy.current_hp = 0

	manager._collect_reward_if_dead(enemy)
	assert(enemy.rewards_collected)
	assert(manager.state.team_general_cards.size() == initial_card_count + 1)
	assert(manager.state.team_general_cards[-1].is_general())
	assert(is_equal_approx(manager.state.new_toefl, initial_toefl + enemy.toefl_reward))

	manager._collect_reward_if_dead(enemy)
	assert(manager.state.team_general_cards.size() == initial_card_count + 1)
	assert(is_equal_approx(manager.state.new_toefl, initial_toefl + enemy.toefl_reward))

	quit()
