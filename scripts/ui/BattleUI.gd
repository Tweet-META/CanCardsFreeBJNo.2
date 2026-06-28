extends Control
## Defines the BattleUI script.
class_name BattleUI

signal card_use_requested(character_index: int, card_index: int, enemy_index: int, ally_index: int, difficulty: String)
signal shop_refresh_requested()
signal shop_buy_requested(offer_index: int, character_index: int)
signal general_card_sell_requested(card_index: int)
signal developer_add_culture_mask_requested()
signal developer_add_general_card_requested()
signal six_seven_requested()
signal developer_clear_enemies_requested()
signal developer_defeat_players_requested()
signal developer_skip_turn_requested()

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


## Ready.
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
	developer_controls.clear_enemies_requested.connect(func() -> void: developer_clear_enemies_requested.emit())
	developer_controls.defeat_players_requested.connect(func() -> void: developer_defeat_players_requested.emit())
	developer_controls.skip_turn_requested.connect(func() -> void: developer_skip_turn_requested.emit())
	LanguageManager.language_changed.connect(_on_language_changed)


## Process.
func _process(delta: float) -> void:
	if hand_controller.dragging_card_index == -1:
		hand_controller.process_hover_restore(delta, get_global_mouse_position())
		return
	var mouse_position: Vector2 = get_global_mouse_position()
	arrow_layer.update_arrow(mouse_position)
	_update_drag_target_highlight(mouse_position)
	_update_cancel_drop_hover(mouse_position)
	top_bar.update_sell_drop_hover(mouse_position)


## Input.
func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		_process_hidden_code_key(event as InputEventKey)
	if hand_controller.dragging_card_index == -1:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		_release_dragging_card(hand_controller.dragging_card_index, get_global_mouse_position())
		accept_event()


## Apply export safe layout.
func _apply_export_safe_layout() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	offset_left = 0.0
	offset_top = 0.0
	offset_right = 0.0
	offset_bottom = 0.0


## Process hidden code key.
func _process_hidden_code_key(event: InputEventKey) -> void:
	var typed_character: String = char(event.unicode)
	if typed_character < "0" or typed_character > "9":
		return
	hidden_code_buffer = (hidden_code_buffer + typed_character).right(SIX_SEVEN_CODE.length())
	if hidden_code_buffer == SIX_SEVEN_CODE:
		hidden_code_buffer = ""
		six_seven_requested.emit()


## Refresh.
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


## Add log.
func add_log(_message: String) -> void:
	if state != null:
		_refresh_logs()


## On language changed.
func _on_language_changed(_locale: String) -> void:
	if state != null:
		refresh(state)


## Refresh status.
func _refresh_status() -> void:
	top_bar.refresh(state.ap, state.phase, state.turn_count, state.current_wave, state.total_waves)
	_refresh_battle_background()
	_refresh_info_hint()
	_refresh_shop_panel()


## Refresh battle background.
func _refresh_battle_background() -> void:
	if not state.battle_background.is_empty():
		background.texture = load(state.battle_background) as Texture2D


## Refresh battlefield.
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


## Refresh cards.
func _refresh_cards() -> void:
	var character: CharacterData = _get_selected_character()
	rendered_character_index = hand_controller.refresh(state, character, selected_character_index, rendered_character_index)


## Set card interaction locked.
func set_card_interaction_locked(locked: bool) -> void:
	flow_cards_interaction_locked = locked
	_update_effective_card_interaction_lock()


## Update effective card interaction lock.
func _update_effective_card_interaction_lock() -> void:
	var should_lock: bool = flow_cards_interaction_locked or (shop_panel != null and shop_panel.visible)
	_set_effective_card_interaction_locked(should_lock)


## Set effective card interaction locked.
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


## Cancel current card interaction.
func _cancel_current_card_interaction() -> void:
	if hand_controller.dragging_card_index != -1:
		arrow_layer.end_arrow()
		top_bar.end_sell_mode()
		_set_cancel_drop_visible(false)
		_clear_drag_target_highlight()
	hand_controller.set_interaction_locked(true)


## Refresh logs.
func _refresh_logs() -> void:
	if log_panel != null and state != null:
		log_panel.set_messages(state.battle_log)


## On card clicked.
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


## On card drag started.
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


## On card drag moved.
func _on_card_drag_moved(global_position: Vector2) -> void:
	if cards_interaction_locked:
		return
	arrow_layer.update_arrow(global_position)
	_update_drag_target_highlight(global_position)
	top_bar.update_sell_drop_hover(global_position)


## On card drag released.
func _on_card_drag_released(card_index: int, global_position: Vector2) -> void:
	if cards_interaction_locked:
		hand_controller.reset_card_drag_state(card_index)
		return
	_release_dragging_card(card_index, global_position)


## Set cancel drop visible.
func _set_cancel_drop_visible(visible: bool) -> void:
	if cancel_drop_area == null:
		return
	cancel_drop_hovered = false
	if visible:
		cancel_drop_area.show_area()
	else:
		cancel_drop_area.hide_area()


## Update cancel drop hover.
func _update_cancel_drop_hover(global_position: Vector2) -> void:
	if cancel_drop_area == null or not cancel_drop_area.visible:
		return
	var next_hovered: bool = _is_over_cancel_drop_area(global_position)
	if next_hovered == cancel_drop_hovered:
		return
	cancel_drop_hovered = next_hovered
	cancel_drop_area.set_hovered(cancel_drop_hovered)


## Is over cancel drop area.
func _is_over_cancel_drop_area(global_position: Vector2) -> bool:
	if cancel_drop_area == null or not cancel_drop_area.visible:
		return false
	return _control_contains_global_point(cancel_drop_area, global_position)


## Release dragging card.
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


## Try use ally target card.
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


## Try use enemy target card.
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


## Enemy index at.
func _enemy_index_at(global_position: Vector2) -> int:
	return battlefield_controller.enemy_index_at(global_position)


## Player index at.
func _player_index_at(global_position: Vector2) -> int:
	return battlefield_controller.player_index_at(global_position)


## Update drag target highlight.
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


## Clear drag target highlight.
func _clear_drag_target_highlight() -> void:
	if hovered_player_target_index == -1 and hovered_enemy_target_index == -1:
		return
	hovered_player_target_index = -1
	hovered_enemy_target_index = -1
	_refresh_battlefield()


## Select character.
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


## Select enemy.
func _select_enemy(index: int) -> void:
	if state == null or index < 0 or index >= state.enemy_team.size():
		return
	if not state.enemy_team[index].is_alive():
		return
	selected_enemy_index = index
	showing_enemy_info = true
	_refresh_status()
	_refresh_battlefield()


## Refresh info hint.
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


## Toggle shop panel.
func _toggle_shop_panel() -> void:
	if shop_panel == null:
		return
	shop_panel.toggle()
	if shop_panel.visible:
		_refresh_shop_panel()


## On shop visibility changed.
func _on_shop_visibility_changed() -> void:
	_update_effective_card_interaction_lock()


## Refresh shop panel.
func _refresh_shop_panel() -> void:
	if shop_panel == null or state == null:
		return
	shop_panel.refresh(state.new_toefl, state.shop_offer_cards, state.ap)


## Buy shop card.
func _buy_shop_card(offer_index: int) -> void:
	if state == null:
		return
	shop_buy_requested.emit(offer_index, selected_character_index)


## Get selected character.
func _get_selected_character() -> CharacterData:
	if state == null:
		return null
	if selected_character_index < 0 or selected_character_index >= state.player_team.size():
		return null
	return state.player_team[selected_character_index]


## Clamp selection.
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


## First alive enemy index.
func _first_alive_enemy_index() -> int:
	for i in state.enemy_team.size():
		if state.enemy_team[i].is_alive():
			return i
	return -1


## Select next ready character if needed.
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


## Control contains global point.
func _control_contains_global_point(control: Control, global_position: Vector2) -> bool:
	var local_position: Vector2 = control.get_global_transform_with_canvas().affine_inverse() * global_position
	return Rect2(Vector2.ZERO, control.size).has_point(local_position)
