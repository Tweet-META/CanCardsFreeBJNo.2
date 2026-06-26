extends Control
## 战斗界面协调器；刷新各 UI 面板，并把玩家交互意图转发给 BattleManager。
class_name BattleUI

signal card_use_requested(character_index: int, card_index: int, enemy_index: int, ally_index: int, difficulty: String)
signal shop_refresh_requested()
signal shop_buy_requested(offer_index: int, character_index: int)
signal general_card_sell_requested(card_index: int)
signal developer_add_culture_mask_requested()
signal developer_add_general_card_requested()
signal six_seven_requested()

const SIX_SEVEN_CODE: String = "676767"

var state: BattleState
var selected_character_index: int = 0
var selected_enemy_index: int = 0
var previous_character_index: int = -1
var rendered_character_index: int = -1
var showing_enemy_info: bool = false
var selection_transition_pending: bool = false
var hovered_player_target_index: int = -1
var hovered_enemy_target_index: int = -1
var cancel_drop_hovered: bool = false
var flow_cards_interaction_locked: bool = false
var cards_interaction_locked: bool = false
var hidden_code_buffer: String = ""
var battlefield_controller: BattlefieldController = BattlefieldController.new()
var hand_controller: BattleHandController = BattleHandController.new()

@onready var background: TextureRect = $Background
@onready var top_bar: BattleTopBar = $Root/BattleTopBar
@onready var battlefield: Control = $Root/Battlefield
@onready var player_layer: Control = $Root/Battlefield/PlayerLayer
@onready var enemy_layer: Control = $Root/Battlefield/EnemyLayer
@onready var arrow_layer: ArrowLayer = $Root/Battlefield/ArrowLayer
@onready var cancel_drop_area: CancelDropArea = $Root/Battlefield/CancelDropArea
@onready var exclusive_cards: Control = $Root/Bottom/CardsArea/ExclusiveCards
@onready var general_cards: Control = $Root/Bottom/CardsArea/GeneralCards
@onready var log_panel: BattleLogPanel = $Root/Bottom/BattleLogPanel
@onready var selected_hint: BattleInfoPanel = $BattleInfoPanel
@onready var shop_panel: ShopPanel = $ShopPanel
@onready var developer_controls: DeveloperControls = $DeveloperControls


## 初始化战斗 UI 子控制器，并连接所有 UI 到 UI 的本地信号。
func _ready() -> void:
	set_process(true)
	set_process_input(true)
	_apply_export_safe_layout()
	battlefield_controller.setup(self, battlefield, player_layer, enemy_layer)
	battlefield_controller.character_selected.connect(_select_character)
	battlefield_controller.enemy_selected.connect(_select_enemy)
	hand_controller.setup(exclusive_cards, general_cards)
	hand_controller.card_clicked.connect(_on_card_clicked)
	hand_controller.drag_started.connect(_on_card_drag_started)
	hand_controller.drag_moved.connect(_on_card_drag_moved)
	hand_controller.drag_released.connect(_on_card_drag_released)
	top_bar.menu_requested.connect(func() -> void: get_tree().change_scene_to_file("res://scenes/MapScene.tscn"))
	top_bar.shop_requested.connect(_toggle_shop_panel)
	shop_panel.refresh_requested.connect(func() -> void: shop_refresh_requested.emit())
	shop_panel.buy_requested.connect(_buy_shop_card)
	shop_panel.visibility_changed.connect(_on_shop_visibility_changed)
	developer_controls.add_culture_mask_requested.connect(func() -> void: developer_add_culture_mask_requested.emit())
	developer_controls.add_general_card_requested.connect(func() -> void: developer_add_general_card_requested.emit())
	developer_controls.add_six_seven_requested.connect(func() -> void: six_seven_requested.emit())
	LanguageManager.language_changed.connect(_on_language_changed)


## 每帧更新拖牌箭头、目标高亮、卖牌区和取消区。
func _process(delta: float) -> void:
	if hand_controller.dragging_card_index == -1:
		hand_controller.process_hover_restore(delta, get_global_mouse_position())
		return
	var mouse_position: Vector2 = get_global_mouse_position()
	arrow_layer.update_arrow(mouse_position)
	_update_drag_target_highlight(mouse_position)
	_update_cancel_drop_hover(mouse_position)
	top_bar.update_sell_drop_hover(mouse_position)


## 处理隐藏口令和拖牌时的全局鼠标松开兜底。
func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		_process_hidden_code_key(event as InputEventKey)
	if hand_controller.dragging_card_index == -1:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		_release_dragging_card(hand_controller.dragging_card_index, get_global_mouse_position())
		accept_event()


## 恢复 BattleUI 根节点在导出版本中的全屏锚点。
func _apply_export_safe_layout() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	offset_left = 0.0
	offset_top = 0.0
	offset_right = 0.0
	offset_bottom = 0.0


## 读取数字输入，并在输入 676767 时发放彩蛋卡。
func _process_hidden_code_key(event: InputEventKey) -> void:
	var typed_character: String = char(event.unicode)
	if typed_character < "0" or typed_character > "9":
		return
	hidden_code_buffer = (hidden_code_buffer + typed_character).right(SIX_SEVEN_CODE.length())
	if hidden_code_buffer == SIX_SEVEN_CODE:
		hidden_code_buffer = ""
		six_seven_requested.emit()


## 接收 BattleManager 的完整状态快照并刷新所有战斗 UI。
func refresh(new_state: BattleState) -> void:
	state = new_state
	if top_bar == null:
		return
	_clamp_selection()
	_select_next_ready_character_if_needed()
	_refresh_status()
	_refresh_battlefield()
	_refresh_cards()
	_refresh_logs()


## 战斗日志新增时重绘日志面板。
func add_log(_message: String) -> void:
	if state != null:
		_refresh_logs()


## 语言变化时用当前状态重刷全部文本。
func _on_language_changed(_locale: String) -> void:
	if state != null:
		refresh(state)


## 刷新顶部栏、背景、信息栏和商店金额。
func _refresh_status() -> void:
	top_bar.refresh(state.ap, state.phase, state.turn_count, state.current_wave, state.total_waves)
	_refresh_battle_background()
	_refresh_info_hint()
	_refresh_shop_panel()


## 根据当前关卡数据切换战斗背景。
func _refresh_battle_background() -> void:
	if not state.battle_background.is_empty():
		background.texture = load(state.battle_background) as Texture2D


## 让战场控制器刷新角色、敌人、血条、效果和目标高亮。
func _refresh_battlefield() -> void:
	battlefield_controller.refresh(
		state,
		selected_character_index,
		previous_character_index,
		selection_transition_pending,
		selected_enemy_index,
		showing_enemy_info,
		hovered_player_target_index,
		hovered_enemy_target_index
	)
	selection_transition_pending = false


## 刷新专属手牌和队伍通用手牌。
func _refresh_cards() -> void:
	var character: CharacterData = _get_selected_character()
	rendered_character_index = hand_controller.refresh(state, character, selected_character_index, rendered_character_index)


## 设置流程层面的卡牌交互锁，例如答题、结算或商店打开时。
func set_card_interaction_locked(locked: bool) -> void:
	flow_cards_interaction_locked = locked
	_update_effective_card_interaction_lock()


## 合并流程锁与商店锁，得到最终是否禁用卡牌。
func _update_effective_card_interaction_lock() -> void:
	var should_lock: bool = flow_cards_interaction_locked or (shop_panel != null and shop_panel.visible)
	_set_effective_card_interaction_locked(should_lock)


## 切换实际卡牌交互锁，并在解锁时恢复当前可行动角色。
func _set_effective_card_interaction_locked(locked: bool) -> void:
	if cards_interaction_locked == locked:
		return
	cards_interaction_locked = locked
	if cards_interaction_locked:
		_cancel_current_card_interaction()
	else:
		hand_controller.set_interaction_locked(false)
		if state != null:
			_select_next_ready_character_if_needed()
			_refresh_status()
			_refresh_battlefield()
			_refresh_cards()


## 清理手牌、箭头、卖牌、取消区和目标高亮。
func _cancel_current_card_interaction() -> void:
	if hand_controller.dragging_card_index != -1:
		arrow_layer.end_arrow()
		top_bar.end_sell_mode()
		_set_cancel_drop_visible(false)
		_clear_drag_target_highlight()
	hand_controller.set_interaction_locked(true)


## 刷新折叠日志按钮或展开日志内容。
func _refresh_logs() -> void:
	if log_panel != null and state != null:
		log_panel.set_messages(state.battle_log)


## 处理点击卡牌：无需指定目标的卡牌可以直接发出使用请求。
func _on_card_clicked(card_index: int) -> void:
	if cards_interaction_locked:
		return
	var character: CharacterData = _get_selected_character()
	if character == null:
		return
	var card: CardData = hand_controller.get_card_for_ui_index(state, character, card_index)
	if card == null:
		return
	if card.targets_single_enemy() or card.targets_ally():
		return
	if card.is_general():
		await hand_controller.play_general_card_consume_animation(self, card_index)
		if state == null or state.phase != BattleState.Phase.PLAYER_TURN:
			return
	card_use_requested.emit(selected_character_index, card_index, -1, -1, "")


## 拖动开始时显示箭头、取消区，通用卡额外让商店按钮变为卖出区。
func _on_card_drag_started(card_index: int, global_position: Vector2) -> void:
	if cards_interaction_locked:
		hand_controller.reset_card_drag_state(card_index)
		return
	hovered_player_target_index = -1
	hovered_enemy_target_index = -1
	_set_cancel_drop_visible(true)
	arrow_layer.begin_arrow(global_position, global_position)
	var character: CharacterData = _get_selected_character()
	var card: CardData = hand_controller.get_card_for_ui_index(state, character, card_index) if character != null else null
	if card != null and card.is_general():
		top_bar.begin_sell_mode(card.get_sell_price())


## 拖动移动时更新箭头、合法目标高亮和卖牌区高亮。
func _on_card_drag_moved(global_position: Vector2) -> void:
	if cards_interaction_locked:
		return
	arrow_layer.update_arrow(global_position)
	_update_drag_target_highlight(global_position)
	top_bar.update_sell_drop_hover(global_position)


## 拖动松开时进入统一落点判定。
func _on_card_drag_released(card_index: int, global_position: Vector2) -> void:
	if cards_interaction_locked:
		hand_controller.reset_card_drag_state(card_index)
		return
	_release_dragging_card(card_index, global_position)


## 显示或隐藏下方取消使用区域。
func _set_cancel_drop_visible(visible: bool) -> void:
	if cancel_drop_area == null:
		return
	cancel_drop_hovered = false
	if visible:
		cancel_drop_area.show_area()
	else:
		cancel_drop_area.hide_area()


## 更新取消区域的悬停高亮。
func _update_cancel_drop_hover(global_position: Vector2) -> void:
	if cancel_drop_area == null or not cancel_drop_area.visible:
		return
	var next_hovered: bool = _is_over_cancel_drop_area(global_position)
	if next_hovered == cancel_drop_hovered:
		return
	cancel_drop_hovered = next_hovered
	cancel_drop_area.set_hovered(cancel_drop_hovered)


## 判断鼠标是否落在取消区域。
func _is_over_cancel_drop_area(global_position: Vector2) -> bool:
	if cancel_drop_area == null or not cancel_drop_area.visible:
		return false
	return _control_contains_global_point(cancel_drop_area, global_position)


## 判定拖牌落点：取消、卖出、友方目标、敌方目标或直接使用。
func _release_dragging_card(card_index: int, global_position: Vector2) -> void:
	if cards_interaction_locked or hand_controller.dragging_card_index == -1:
		return
	var sold_to_shop: bool = top_bar.is_sell_drop_target(global_position)
	var cancelled_by_drop_area: bool = _is_over_cancel_drop_area(global_position)
	arrow_layer.end_arrow()
	top_bar.end_sell_mode()
	hand_controller.finish_drag(card_index)
	_set_cancel_drop_visible(false)
	_clear_drag_target_highlight()
	if cancelled_by_drop_area:
		hand_controller.restore_hover_after_cancel(global_position)
		return

	var character: CharacterData = _get_selected_character()
	if character == null:
		hand_controller.restore_hover_after_cancel(global_position)
		return
	var card: CardData = hand_controller.get_card_for_ui_index(state, character, card_index)
	if card == null:
		hand_controller.restore_hover_after_cancel(global_position)
		return
	if sold_to_shop and card.is_general():
		general_card_sell_requested.emit(card_index)
		return
	if card.targets_ally():
		_try_use_ally_target_card(card, card_index, global_position)
		return
	if card.targets_single_enemy():
		_try_use_enemy_target_card(card, card_index, global_position)
		return
	if card.target_type == CardData.TargetType.ALL_ENEMIES or card.is_general():
		card_use_requested.emit(selected_character_index, card_index, -1, -1, "")
		return
	hand_controller.restore_hover_after_cancel(global_position)


## 尝试把一张需要友方目标的卡牌用到鼠标下方角色身上。
func _try_use_ally_target_card(card: CardData, card_index: int, global_position: Vector2) -> void:
	var ally_index: int = _player_index_at(global_position)
	if ally_index == -1:
		hand_controller.restore_hover_after_cancel(global_position)
		return
	if card.is_general():
		await hand_controller.play_general_card_consume_animation(self, card_index)
		if state == null or state.phase != BattleState.Phase.PLAYER_TURN:
			return
	card_use_requested.emit(selected_character_index, card_index, -1, ally_index, "")


## 尝试把一张需要敌方目标的卡牌用到鼠标下方敌人身上。
func _try_use_enemy_target_card(card: CardData, card_index: int, global_position: Vector2) -> void:
	var enemy_index: int = _enemy_index_at(global_position)
	if enemy_index == -1:
		hand_controller.restore_hover_after_cancel(global_position)
		return
	selected_enemy_index = enemy_index
	if card.is_general():
		await hand_controller.play_general_card_consume_animation(self, card_index)
		if state == null or state.phase != BattleState.Phase.PLAYER_TURN:
			return
	card_use_requested.emit(selected_character_index, card_index, enemy_index, -1, "")


## 返回鼠标下方敌人的数组索引。
func _enemy_index_at(global_position: Vector2) -> int:
	return battlefield_controller.enemy_index_at(global_position)


## 返回鼠标下方我方角色的数组索引。
func _player_index_at(global_position: Vector2) -> int:
	return battlefield_controller.player_index_at(global_position)


## 拖动时只高亮当前卡牌允许选择的目标。
func _update_drag_target_highlight(global_position: Vector2) -> void:
	var character: CharacterData = _get_selected_character()
	if character == null or hand_controller.dragging_card_index == -1:
		_clear_drag_target_highlight()
		return
	var card: CardData = hand_controller.get_card_for_ui_index(state, character, hand_controller.dragging_card_index)
	if card == null:
		_clear_drag_target_highlight()
		return

	var next_player_index: int = -1
	var next_enemy_index: int = -1
	if card.targets_ally():
		next_player_index = _player_index_at(global_position)
	elif card.targets_single_enemy():
		next_enemy_index = _enemy_index_at(global_position)

	if next_player_index == hovered_player_target_index and next_enemy_index == hovered_enemy_target_index:
		return
	hovered_player_target_index = next_player_index
	hovered_enemy_target_index = next_enemy_index
	_refresh_battlefield()


## 清除拖牌目标高亮。
func _clear_drag_target_highlight() -> void:
	if hovered_player_target_index == -1 and hovered_enemy_target_index == -1:
		return
	hovered_player_target_index = -1
	hovered_enemy_target_index = -1
	_refresh_battlefield()


## 点击我方角色时切换出牌者，并触发角色与专属卡切换动画。
func _select_character(index: int) -> void:
	if state == null or index < 0 or index >= state.player_team.size():
		return
	if not state.player_team[index].is_alive():
		return
	if index != selected_character_index:
		previous_character_index = selected_character_index
		selection_transition_pending = true
	selected_character_index = index
	showing_enemy_info = false
	_refresh_status()
	_refresh_battlefield()
	_refresh_cards()


## 点击敌人时把左下角信息栏切到敌人描述。
func _select_enemy(index: int) -> void:
	if state == null or index < 0 or index >= state.enemy_team.size():
		return
	if not state.enemy_team[index].is_alive():
		return
	selected_enemy_index = index
	showing_enemy_info = true
	_refresh_status()
	_refresh_battlefield()


## 刷新左下角角色或敌人的自由描述文本。
func _refresh_info_hint() -> void:
	if selected_hint == null or state == null:
		return
	if showing_enemy_info and selected_enemy_index >= 0 and selected_enemy_index < state.enemy_team.size():
		var enemy: EnemyData = state.enemy_team[selected_enemy_index]
		selected_hint.text = tr(enemy.description).replace("\\n", "\n")
		return

	var character: CharacterData = _get_selected_character()
	if character == null:
		selected_hint.text = ""
		return
	selected_hint.text = tr(character.description).replace("\\n", "\n")


## 打开或关闭商店面板。
func _toggle_shop_panel() -> void:
	if shop_panel == null:
		return
	shop_panel.toggle()
	if shop_panel.visible:
		_refresh_shop_panel()


## 商店显隐变化时重新计算卡牌锁。
func _on_shop_visibility_changed() -> void:
	_update_effective_card_interaction_lock()


## 刷新商店余额、货架卡牌和刷新按钮状态。
func _refresh_shop_panel() -> void:
	if shop_panel == null or state == null:
		return
	shop_panel.refresh(state.new_toefl, state.shop_offer_cards, state.ap)


## 转发购买商店卡牌的请求。
func _buy_shop_card(offer_index: int) -> void:
	if state == null:
		return
	shop_buy_requested.emit(offer_index, selected_character_index)


## 返回当前选中的我方角色。
func _get_selected_character() -> CharacterData:
	if state == null:
		return null
	if selected_character_index < 0 or selected_character_index >= state.player_team.size():
		return null
	return state.player_team[selected_character_index]


## 状态刷新后修正越界或死亡目标，避免使用失效索引。
func _clamp_selection() -> void:
	if state.player_team.is_empty():
		selected_character_index = -1
	else:
		selected_character_index = clampi(selected_character_index, 0, state.player_team.size() - 1)
	if state.enemy_team.is_empty():
		selected_enemy_index = -1
	else:
		selected_enemy_index = clampi(selected_enemy_index, 0, state.enemy_team.size() - 1)
		if not state.enemy_team[selected_enemy_index].is_alive():
			selected_enemy_index = _first_alive_enemy_index()
			if selected_enemy_index == -1:
				showing_enemy_info = false


## 找到第一名存活敌人，用于选中目标死亡后的 UI 回退。
func _first_alive_enemy_index() -> int:
	for i in state.enemy_team.size():
		if state.enemy_team[i].is_alive():
			return i
	return -1


## 若当前角色已行动或死亡，自动切到下一名可行动角色。
func _select_next_ready_character_if_needed() -> void:
	if state.phase != BattleState.Phase.PLAYER_TURN:
		return
	if selected_character_index >= 0 and selected_character_index < state.player_team.size():
		var selected: CharacterData = state.player_team[selected_character_index]
		if selected.is_alive() and not selected.has_acted:
			return

	for i in state.player_team.size():
		var character: CharacterData = state.player_team[i]
		if character.is_alive() and not character.has_acted:
			if i != selected_character_index:
				previous_character_index = selected_character_index
				selection_transition_pending = true
			selected_character_index = i
			return


## 判断 Control 的本地矩形是否包含某个全局坐标。
func _control_contains_global_point(control: Control, global_position: Vector2) -> bool:
	var local_position: Vector2 = control.get_global_transform_with_canvas().affine_inverse() * global_position
	return Rect2(Vector2.ZERO, control.size).has_point(local_position)
