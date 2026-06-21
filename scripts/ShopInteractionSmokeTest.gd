extends SceneTree
## 验证商店显示时锁定所有手牌，并确认通用卡绘制在敌人层之上。


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var packed_scene: PackedScene = load("res://scenes/BattleScene.tscn") as PackedScene
	assert(packed_scene != null)
	var scene: Node = packed_scene.instantiate()
	root.add_child(scene)
	await process_frame

	var battle_ui: BattleUI = scene.get_node("CanvasLayer/BattleUI") as BattleUI
	assert(battle_ui != null)
	assert(battle_ui.general_cards.z_index > BattlefieldController.ENEMY_BASE_Z_INDEX + 500)
	assert(not battle_ui.cards_interaction_locked)

	battle_ui.shop_panel.show()
	await process_frame
	assert(battle_ui.cards_interaction_locked)
	_assert_group_locked(battle_ui.exclusive_cards)
	_assert_group_locked(battle_ui.general_cards)

	battle_ui.shop_panel.hide()
	await process_frame
	assert(not battle_ui.cards_interaction_locked)

	# 关闭商店不能覆盖答题/结算流程持有的锁。
	battle_ui.set_card_interaction_locked(true)
	battle_ui.shop_panel.show()
	battle_ui.shop_panel.hide()
	await process_frame
	assert(battle_ui.cards_interaction_locked)

	quit()


func _assert_group_locked(group: Control) -> void:
	for child: Node in group.get_children():
		if child is CardButton:
			var card_button: CardButton = child as CardButton
			assert(card_button.interaction_locked)
