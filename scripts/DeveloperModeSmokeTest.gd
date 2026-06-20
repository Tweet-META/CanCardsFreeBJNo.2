extends SceneTree


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	SettingsManager.set_developer_mode(true)

	var packed_scene: PackedScene = load("res://scenes/BattleScene.tscn")
	assert(packed_scene != null)
	var scene: Node = packed_scene.instantiate()
	root.add_child(scene)
	await process_frame

	var manager: BattleManager = scene.get_node("BattleManager")
	var battle_ui: BattleUI = scene.get_node("CanvasLayer/BattleUI")
	assert(battle_ui.developer_controls.visible)

	var initial_enemy_count: int = manager.state.enemy_team.size()
	manager.developer_add_festival_mask()
	assert(manager.state.enemy_team.size() == initial_enemy_count + 1)
	assert(manager.state.enemy_team[-1].display_name == "ENEMY_FESTIVAL_MASK")

	var initial_card_count: int = manager.state.team_general_cards.size()
	manager.developer_add_general_card()
	assert(manager.state.team_general_cards.size() == initial_card_count + 1)
	assert(manager.state.team_general_cards[-1].display_name == "CARD_GENERAL_1")

	while manager.state.get_alive_enemies().size() < 8:
		manager.developer_add_festival_mask()
	var capped_count: int = manager.state.enemy_team.size()
	manager.developer_add_festival_mask()
	assert(manager.state.enemy_team.size() == capped_count)

	SettingsManager.set_developer_mode(false)
	assert(not battle_ui.developer_controls.visible)
	quit()
