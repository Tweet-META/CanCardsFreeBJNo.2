extends Node2D
## Documents this script block.

@onready var battle_manager: BattleManager = $BattleManager
@onready var battle_ui: BattleUI = $CanvasLayer/BattleUI
@onready var question_panel: QuestionPanel = $QuestionLayer/QuestionPanel
@onready var result_panel: ResultPanel = $QuestionLayer/ResultPanel


## Ready.
func _ready() -> void:
	battle_ui.card_use_requested.connect(battle_manager.request_use_card)
	battle_ui.shop_refresh_requested.connect(battle_manager.request_refresh_shop)
	battle_ui.shop_buy_requested.connect(battle_manager.request_buy_shop_card)
	battle_ui.general_card_sell_requested.connect(battle_manager.request_sell_general_card)
	battle_ui.developer_add_culture_mask_requested.connect(battle_manager.developer_add_culture_mask)
	battle_ui.developer_add_general_card_requested.connect(battle_manager.developer_add_general_card)
	battle_ui.six_seven_requested.connect(battle_manager.grant_six_seven)
	battle_ui.developer_clear_enemies_requested.connect(battle_manager.developer_clear_enemies)
	battle_ui.developer_defeat_players_requested.connect(battle_manager.developer_defeat_players)
	question_panel.difficulty_selected.connect(battle_manager.select_question_difficulty)
	question_panel.answer_submitted.connect(battle_manager.submit_answer)
	result_panel.retry_requested.connect(battle_manager.retry_battle)
	result_panel.menu_requested.connect(_go_to_menu)
	result_panel.dismissed.connect(_on_result_panel_dismissed)

	battle_manager.state_changed.connect(battle_ui.refresh)
	battle_manager.difficulty_requested.connect(_on_difficulty_requested)
	battle_manager.question_requested.connect(_on_question_requested)
	battle_manager.result_requested.connect(_on_result_requested)
	battle_manager.log_added.connect(battle_ui.add_log)

	await get_tree().process_frame
	if battle_manager.state != null:
		battle_ui.refresh(battle_manager.state)


## Go to menu.
func _go_to_menu() -> void:
	get_tree().change_scene_to_file("res://scenes/MapScene.tscn")


## On question requested.
func _on_question_requested(question: QuestionData) -> void:
	battle_ui.set_card_interaction_locked(true)
	question_panel.show_question(question)


## On difficulty requested.
func _on_difficulty_requested() -> void:
	battle_ui.set_card_interaction_locked(true)
	question_panel.show_difficulty_selection()


## On result requested.
func _on_result_requested(title: String, message: String, battle_over: bool, victory: bool) -> void:
	battle_ui.set_card_interaction_locked(true)
	result_panel.show_result(title, message, battle_over, victory)


## On result panel dismissed.
func _on_result_panel_dismissed() -> void:
	battle_ui.set_card_interaction_locked(false)
