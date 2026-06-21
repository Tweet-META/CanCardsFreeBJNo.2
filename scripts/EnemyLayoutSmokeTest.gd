extends SceneTree
## 验证 1～8 只敌人的固定尺寸、斜向站位和死亡后从战场移除。


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var packed_ui: PackedScene = load("res://scenes/ui/BattleUI.tscn")
	assert(packed_ui != null)
	var battle_ui: BattleUI = packed_ui.instantiate() as BattleUI
	root.add_child(battle_ui)
	await process_frame

	var field_size := Vector2(1228, 395)
	var expected_slots: Array[Vector2] = [
		Vector2(0.52, 0.285),
		Vector2(0.08, 0.56),
		Vector2(0.50, 0.83),
		Vector2(0.45, 0.51),
		Vector2(0.70, 0.82),
		Vector2(0.72, 0.29),
		Vector2(0.82, 0.52),
		Vector2(0.83, 0.80)
	]
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
			assert(scale_value == Vector2.ONE)

		var normalized_centers: Array[Vector2] = _normalized_centers(layouts, field_size)
		if count == 1:
			assert(normalized_centers[0].is_equal_approx(Vector2(0.58, 0.50)))
		elif count == 2:
			assert(normalized_centers[0].is_equal_approx(Vector2(0.38, 0.32)))
			assert(normalized_centers[1].is_equal_approx(Vector2(0.70, 0.66)))
		else:
			for slot in count:
				assert(normalized_centers[slot].is_equal_approx(expected_slots[slot]))
			var min_y: float = normalized_centers[0].y
			var max_y: float = normalized_centers[0].y
			for center: Vector2 in normalized_centers:
				min_y = minf(min_y, center.y)
				max_y = maxf(max_y, center.y)
			assert(max_y - min_y >= 0.54)
			if count >= 3:
				var min_x: float = normalized_centers[0].x
				var max_x: float = normalized_centers[0].x
				for center: Vector2 in normalized_centers:
					min_x = minf(min_x, center.x)
					max_x = maxf(max_x, center.x)
				assert(max_x - min_x >= 0.44)

	var enemies: Array[EnemyData] = []
	for i in 8:
		var enemy := EnemyData.new()
		enemy.id = "layout_enemy_%d" % i
		enemy.display_name = "ENEMY_PINYIN_BUN"
		enemy.attribute = BattleState.ATTRIBUTE_PINYIN
		enemy.max_hp = 10
		enemy.portrait_path = "res://assets/enemies/pinyin_bun.png"
		enemies.append(enemy)

	var state := BattleState.new()
	var stage: StageData = StageData.new()
	stage.id = "layout_test"
	stage.waves = [StageWaveData.new()]
	state.setup(GameDataFactory.create_player_team(), enemies, stage)
	state.start_player_turn()
	battle_ui.refresh(state)
	await process_frame
	assert(battle_ui.enemy_layer.get_child_count() == 8)
	for standee_value: Variant in battle_ui.battlefield_controller.enemy_standees.values():
		var standee: EnemyStandee = standee_value as EnemyStandee
		assert(standee != null)
		assert(standee.z_index >= BattlefieldController.ENEMY_BASE_Z_INDEX)
		assert(standee.modulate == Color.WHITE)

	enemies[3].current_hp = 0
	battle_ui.refresh(state)
	await process_frame
	assert(battle_ui.enemy_layer.get_child_count() == 7)
	assert(not battle_ui.battlefield_controller.enemy_standees.has(3))

	quit()


func _normalized_centers(layouts: Array[Dictionary], field_size: Vector2) -> Array[Vector2]:
	# 将实际像素布局还原成槽位坐标，避免缩放变化掩盖站位重排。
	var enemy_region := Rect2(
		Vector2(field_size.x * 0.55, field_size.y * 0.02),
		Vector2(field_size.x * 0.43, field_size.y * 0.86)
	)
	var centers: Array[Vector2] = []
	for layout: Dictionary in layouts:
		var position_value: Vector2 = layout["position"]
		var scale_value: Vector2 = layout["scale"]
		var visual_size: Vector2 = Vector2(220, 210) * scale_value
		var center: Vector2 = position_value + visual_size * 0.5
		centers.append((center - enemy_region.position) / enemy_region.size)
	return centers
