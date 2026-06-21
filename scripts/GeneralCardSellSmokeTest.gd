extends SceneTree
## 验证通用牌出售价格、牌堆移除和角色行动状态不会被出售行为修改。


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var rounding_card: CardData = CardData.new()
	rounding_card.shop_price = 0.8
	assert(is_equal_approx(rounding_card.get_sell_price(), 0.5))

	var packed_scene: PackedScene = load("res://scenes/BattleScene.tscn") as PackedScene
	assert(packed_scene != null)
	var scene: Node = packed_scene.instantiate()
	root.add_child(scene)
	await process_frame

	var manager: BattleManager = scene.get_node("BattleManager") as BattleManager
	var battle_ui: BattleUI = scene.get_node("CanvasLayer/BattleUI") as BattleUI
	assert(manager != null)
	assert(battle_ui != null)
	assert(not manager.state.team_general_cards.is_empty())
	var original_count: int = manager.state.team_general_cards.size()
	var sold_card: CardData = manager.state.team_general_cards[0]
	var expected_price: float = sold_card.get_sell_price()
	var original_balance: float = manager.state.new_toefl
	var original_acted: bool = manager.state.player_team[0].has_acted
	var encoded_index: int = -BattleManager.TEAM_GENERAL_CARD_INDEX_OFFSET

	battle_ui._on_card_drag_started(encoded_index, Vector2.ZERO)
	assert(battle_ui.top_bar.sell_mode)
	var shop_center: Vector2 = battle_ui.top_bar.shop_button.get_global_transform_with_canvas() * (battle_ui.top_bar.shop_button.size * 0.5)
	battle_ui._release_dragging_card(encoded_index, shop_center)
	await process_frame

	assert(manager.state.team_general_cards.size() == original_count - 1)
	assert(is_equal_approx(manager.state.new_toefl, minf(6.0, original_balance + expected_price)))
	assert(manager.state.player_team[0].has_acted == original_acted)
	assert(not battle_ui.top_bar.sell_mode)

	quit()
