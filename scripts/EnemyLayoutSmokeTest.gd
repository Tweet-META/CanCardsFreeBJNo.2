extends SceneTree


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var packed_ui: PackedScene = load("res://scenes/ui/BattleUI.tscn")
	assert(packed_ui != null)
	var battle_ui: BattleUI = packed_ui.instantiate() as BattleUI
	root.add_child(battle_ui)
	await process_frame

	var field_size := Vector2(1228, 395)
	var previous_scale: float = 2.0
	for count in range(1, 9):
		var layouts: Array[Dictionary] = battle_ui.battlefield_controller.enemy_layout_for_count(count, field_size)
		assert(layouts.size() == count)
		var occupied_positions: Dictionary = {}
		for layout: Dictionary in layouts:
			var position_value: Vector2 = layout["position"]
			var scale_value: Vector2 = layout["scale"]
			assert(position_value.x >= 0.0 and position_value.y >= 0.0)
			assert(position_value.x + 220.0 * scale_value.x <= field_size.x)
			assert(position_value.y + 210.0 * scale_value.y <= field_size.y)
			assert(not occupied_positions.has(position_value))
			occupied_positions[position_value] = true
			assert(scale_value.x <= previous_scale)
		previous_scale = scale_value.x

	var enemies: Array[EnemyData] = []
	for i in 8:
		var enemy := EnemyData.new()
		enemy.id = "layout_enemy_%d" % i
		enemy.display_name = "ENEMY_TONE_BLOB"
		enemy.attribute = BattleState.ATTRIBUTE_PINYIN
		enemy.max_hp = 10
		enemy.portrait_path = "res://assets/enemies/tone_blob.png"
		enemies.append(enemy)

	var state := BattleState.new()
	state.setup(GameDataFactory.create_player_team(), enemies)
	state.start_player_turn()
	battle_ui.refresh(state)
	await process_frame
	assert(battle_ui.enemy_layer.get_child_count() == 8)

	enemies[3].current_hp = 0
	battle_ui.refresh(state)
	await process_frame
	assert(battle_ui.enemy_layer.get_child_count() == 7)
	assert(not battle_ui.battlefield_controller.enemy_standees.has(3))

	quit()
