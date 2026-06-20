extends Control
class_name BattleUI

signal card_use_requested(character_index: int, card_index: int, enemy_index: int, ally_index: int, difficulty: String)
signal shop_refresh_requested()
signal shop_buy_requested(offer_index: int, character_index: int)
signal developer_add_festival_mask_requested()
signal developer_add_general_card_requested()

const PAPER: Color = Color(0.86, 0.78, 0.64, 0.96)
const INK: Color = Color(0.12, 0.10, 0.08)
const CARD_SIZE: Vector2 = Vector2(144, 188)
const HOVERED_HAND_Z_INDEX: int = 100
const HAND_ARC_ANGLE_MIN_DEGREES: float = 9.0
const HAND_ARC_ANGLE_MAX_DEGREES: float = 17.0
const HAND_ARC_RADIUS_MIN: float = 360.0
const HAND_ARC_RADIUS_MAX: float = 900.0
const HAND_PIVOT_Y_OFFSET_FACTOR: float = 0.92
const HAND_BOTTOM_PADDING: float = 6.0
const HAND_HOVER_LIFT: float = 38.0
const HAND_HOVER_NEIGHBOR_PUSH: float = 14.0
const HAND_HOVER_SECONDARY_PUSH: float = 6.0
const GENERAL_HAND_LEFT_SHIFT: float = 24.0
const TEAM_GENERAL_CARD_INDEX_OFFSET: int = 1000
const CARD_BUTTON_SCENE: PackedScene = preload("res://scenes/CardButton.tscn")

var state: BattleState

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

var selected_character_index: int = 0
var selected_enemy_index: int = 0
var previous_character_index: int = -1
var rendered_character_index: int = -1
var showing_enemy_info: bool = false
var selection_transition_pending: bool = false
var dragging_card_index: int = -1
var hovered_card_index: int = -1
var hovered_player_target_index: int = -1
var hovered_enemy_target_index: int = -1
var hover_restore_time_left: float = 0.0
var cancel_drop_hovered: bool = false
var cards_interaction_locked: bool = false
var battlefield_controller: BattlefieldController = BattlefieldController.new()


func _ready() -> void:
	set_process(true)
	set_process_input(true)
	battlefield_controller.setup(self, battlefield, player_layer, enemy_layer)
	battlefield_controller.character_selected.connect(_select_character)
	battlefield_controller.enemy_selected.connect(_select_enemy)
	top_bar.menu_requested.connect(func() -> void: get_tree().change_scene_to_file("res://scenes/MainMenu.tscn"))
	top_bar.shop_requested.connect(_toggle_shop_panel)
	shop_panel.refresh_requested.connect(func() -> void: shop_refresh_requested.emit())
	shop_panel.buy_requested.connect(_buy_shop_card)
	developer_controls.add_festival_mask_requested.connect(func() -> void: developer_add_festival_mask_requested.emit())
	developer_controls.add_general_card_requested.connect(func() -> void: developer_add_general_card_requested.emit())
	LanguageManager.language_changed.connect(_on_language_changed)


func _process(delta: float) -> void:
	if dragging_card_index == -1:
		if hover_restore_time_left > 0.0:
			hover_restore_time_left = maxf(0.0, hover_restore_time_left - delta)
			_sync_hovered_card_with_mouse()
		return
	var mouse_position: Vector2 = get_global_mouse_position()
	arrow_layer.update_arrow(mouse_position)
	_update_drag_target_highlight(mouse_position)
	_update_cancel_drop_hover(mouse_position)


func _input(event: InputEvent) -> void:
	if dragging_card_index == -1:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		_release_dragging_card(dragging_card_index, get_global_mouse_position())
		accept_event()


func refresh(new_state: BattleState) -> void:
	state = new_state
	if top_bar == null:
		return
	_clamp_selection()
	_select_next_ready_character_if_needed()
	_refresh_status()
	_refresh_selects()
	_refresh_battlefield()
	_refresh_cards()
	_refresh_logs()


func add_log(_message: String) -> void:
	if state != null:
		_refresh_logs()


func _on_language_changed(_locale: String) -> void:
	if state != null:
		refresh(state)


func _refresh_status() -> void:
	top_bar.refresh(state.ap, state.phase, state.turn_count)
	_refresh_info_hint()
	_refresh_shop_panel()


func _refresh_selects() -> void:
	pass


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


func _refresh_cards() -> void:
	_clear_children(exclusive_cards)
	_clear_children(general_cards)
	var character := _get_selected_character()
	if character == null:
		return

	var exclusive: Array[int] = []
	var general: Array[int] = []
	for i in character.cards.size():
		if not character.cards[i].is_general():
			exclusive.append(i)
	for i in state.team_general_cards.size():
		general.append(_encode_team_general_card_index(i))

	var should_slide_exclusive: bool = rendered_character_index != -1 and rendered_character_index != selected_character_index
	_layout_card_fan(exclusive_cards, character, exclusive, should_slide_exclusive, Vector2(230, 28) if should_slide_exclusive else Vector2.ZERO)
	_layout_card_fan(general_cards, character, general, false)
	rendered_character_index = selected_character_index


func _layout_card_fan(parent: Control, character: CharacterData, indices: Array[int], animate: bool, entry_offset: Vector2 = Vector2.ZERO) -> void:
	var can_click: bool = state.phase == BattleState.Phase.PLAYER_TURN and character.is_alive() and not character.has_acted and not cards_interaction_locked
	var count := indices.size()
	for slot in count:
		var card_index: int = indices[slot]
		var card_data: CardData = _get_card_for_ui_index(character, card_index)
		if card_data == null:
			continue
		var card_button: CardButton = CARD_BUTTON_SCENE.instantiate() as CardButton
		card_button.custom_minimum_size = CARD_SIZE
		card_button.size = card_button.custom_minimum_size
		card_button.pivot_offset = Vector2(CARD_SIZE.x * 0.5, CARD_SIZE.y * HAND_PIVOT_Y_OFFSET_FACTOR)
		card_button.card_selected.connect(_on_card_clicked)
		card_button.drag_started.connect(_on_card_drag_started)
		card_button.drag_moved.connect(_on_card_drag_moved)
		card_button.drag_released.connect(_on_card_drag_released)
		card_button.hover_changed.connect(_on_card_hover_changed)
		parent.add_child(card_button)
		card_button.setup(card_data, card_index, state.ap, can_click)
		card_button.set_interaction_locked(cards_interaction_locked)

		_apply_card_arc_pose(parent, card_button, slot, count, animate, entry_offset)


func set_card_interaction_locked(locked: bool) -> void:
	if cards_interaction_locked == locked:
		return
	cards_interaction_locked = locked
	if cards_interaction_locked:
		_cancel_current_card_interaction()
	else:
		hovered_card_index = -1
		if state != null:
			_select_next_ready_character_if_needed()
			_refresh_status()
			_refresh_battlefield()
			_refresh_cards()
			return
	_apply_card_interaction_lock_to_group(exclusive_cards)
	_apply_card_interaction_lock_to_group(general_cards)


func _cancel_current_card_interaction() -> void:
	if dragging_card_index != -1:
		arrow_layer.end_arrow()
		_reset_card_drag_state(dragging_card_index)
		dragging_card_index = -1
		_set_cancel_drop_visible(false)
		_clear_drag_target_highlight()
	hover_restore_time_left = 0.0
	if hovered_card_index != -1:
		hovered_card_index = -1
		_relayout_existing_cards()


func _apply_card_interaction_lock_to_group(parent: Control) -> void:
	if parent == null:
		return
	for child: Node in parent.get_children():
		if child is CardButton:
			var card_button: CardButton = child
			card_button.set_interaction_locked(cards_interaction_locked)


func _refresh_logs() -> void:
	if log_panel != null and state != null:
		log_panel.set_messages(state.battle_log)


func _on_card_clicked(card_index: int) -> void:
	if cards_interaction_locked:
		return
	var character := _get_selected_character()
	if character == null:
		return
	var use_character_index: int = selected_character_index
	var card: CardData = _get_card_for_ui_index(character, card_index)
	if card == null:
		return
	if card.target_type == CardData.TargetType.SINGLE_ENEMY or card.target_type == CardData.TargetType.ALL_ENEMIES:
		if card.target_type == CardData.TargetType.SINGLE_ENEMY:
			return
		card_use_requested.emit(use_character_index, card_index, -1, -1, _selected_difficulty())
		return
	if _card_targets_ally(card):
		return
	if card.is_general():
		await _play_general_card_consume_animation(card_index)
		if state == null or state.phase != BattleState.Phase.PLAYER_TURN:
			return
	else:
		card_use_requested.emit(use_character_index, card_index, -1, -1, _selected_difficulty())
		return
	card_use_requested.emit(use_character_index, card_index, -1, -1, _selected_difficulty())


func _play_general_card_consume_animation(card_index: int) -> void:
	var card_button: CardButton = _find_card_button(general_cards, card_index)
	if card_button == null:
		return
	card_button.disabled = true
	card_button.z_index = HOVERED_HAND_Z_INDEX + 2

	for i in 12:
		var particle := ColorRect.new()
		particle.color = Color(0.88, 0.78, 0.55, 0.95)
		particle.mouse_filter = Control.MOUSE_FILTER_IGNORE
		particle.size = Vector2(5, 5)
		particle.position = Vector2(CARD_SIZE.x * (0.25 + float(i % 4) * 0.16), CARD_SIZE.y * (0.25 + float(i / 4) * 0.16))
		card_button.add_child(particle)

		var drift: Vector2 = Vector2(float((i % 5) - 2) * 15.0, -44.0 - float(i) * 3.5)
		var particle_tween: Tween = create_tween()
		particle_tween.set_parallel(true)
		particle_tween.set_ease(Tween.EASE_OUT)
		particle_tween.set_trans(Tween.TRANS_CUBIC)
		particle_tween.tween_property(particle, "position", particle.position + drift, 0.34)
		particle_tween.tween_property(particle, "modulate:a", 0.0, 0.34)

	var card_tween: Tween = create_tween()
	card_tween.set_parallel(true)
	card_tween.set_ease(Tween.EASE_OUT)
	card_tween.set_trans(Tween.TRANS_CUBIC)
	card_tween.tween_property(card_button, "position", card_button.position + Vector2(0, -38), 0.34)
	card_tween.tween_property(card_button, "scale", card_button.scale * 0.92, 0.34)
	card_tween.tween_property(card_button, "modulate:a", 0.0, 0.34)
	await card_tween.finished


func _find_card_button(parent: Control, card_index: int) -> CardButton:
	for child: Node in parent.get_children():
		if child is CardButton:
			var card_button: CardButton = child
			if card_button.card_index == card_index:
				return card_button
	return null


func _restore_hover_after_cancel(global_position: Vector2) -> void:
	hover_restore_time_left = 0.36
	hovered_card_index = -1
	_sync_hovered_card_with_mouse(global_position)


func _sync_hovered_card_with_mouse(global_position: Vector2 = Vector2.INF) -> void:
	var check_position: Vector2 = get_global_mouse_position() if global_position == Vector2.INF else global_position
	var next_hovered_card_index: int = _card_index_at_global_position(check_position)
	if next_hovered_card_index == hovered_card_index:
		return
	hovered_card_index = next_hovered_card_index
	_relayout_existing_cards()


func _card_index_at_global_position(global_position: Vector2) -> int:
	var card_index: int = _card_index_at_global_position_in_group(general_cards, global_position)
	if card_index != -1:
		return card_index
	return _card_index_at_global_position_in_group(exclusive_cards, global_position)


func _card_index_at_global_position_in_group(parent: Control, global_position: Vector2) -> int:
	var children: Array[Node] = parent.get_children()
	for i in range(children.size() - 1, -1, -1):
		var child: Node = children[i]
		if child is CardButton:
			var card_button: CardButton = child
			if _control_contains_global_point(card_button, global_position):
				return card_button.card_index
	return -1


func _control_contains_global_point(control: Control, global_position: Vector2) -> bool:
	var local_position: Vector2 = control.get_global_transform_with_canvas().affine_inverse() * global_position
	return Rect2(Vector2.ZERO, control.size).has_point(local_position)


func _get_card_for_ui_index(character: CharacterData, card_index: int) -> CardData:
	if _is_team_general_card_index(card_index):
		var team_card_index: int = _decode_team_general_card_index(card_index)
		if state != null and team_card_index >= 0 and team_card_index < state.team_general_cards.size():
			return state.team_general_cards[team_card_index]
		return null
	if card_index >= 0 and card_index < character.cards.size():
		return character.cards[card_index]
	return null


func _encode_team_general_card_index(team_card_index: int) -> int:
	return -team_card_index - TEAM_GENERAL_CARD_INDEX_OFFSET


func _is_team_general_card_index(card_index: int) -> bool:
	return card_index <= -TEAM_GENERAL_CARD_INDEX_OFFSET


func _decode_team_general_card_index(card_index: int) -> int:
	return -card_index - TEAM_GENERAL_CARD_INDEX_OFFSET


func _on_card_drag_started(card_index: int, global_position: Vector2) -> void:
	if cards_interaction_locked:
		_reset_card_drag_state(card_index)
		return
	dragging_card_index = card_index
	hovered_card_index = -1
	hovered_player_target_index = -1
	hovered_enemy_target_index = -1
	_relayout_existing_cards()
	_set_cancel_drop_visible(true)
	arrow_layer.begin_arrow(global_position, global_position)


func _on_card_drag_moved(global_position: Vector2) -> void:
	if cards_interaction_locked:
		return
	arrow_layer.update_arrow(global_position)
	_update_drag_target_highlight(global_position)


func _on_card_drag_released(card_index: int, global_position: Vector2) -> void:
	if cards_interaction_locked:
		_reset_card_drag_state(card_index)
		return
	_release_dragging_card(card_index, global_position)


func _reset_card_drag_state(card_index: int) -> void:
	var card_button: CardButton = _find_card_button(exclusive_cards, card_index)
	if card_button == null:
		card_button = _find_card_button(general_cards, card_index)
	if card_button != null:
		card_button.reset_drag_state()


func _set_cancel_drop_visible(visible: bool) -> void:
	if cancel_drop_area == null:
		return
	cancel_drop_hovered = false
	if visible:
		cancel_drop_area.show_area()
	else:
		cancel_drop_area.hide_area()


func _update_cancel_drop_hover(global_position: Vector2) -> void:
	if cancel_drop_area == null or not cancel_drop_area.visible:
		return
	var next_hovered: bool = _is_over_cancel_drop_area(global_position)
	if next_hovered == cancel_drop_hovered:
		return
	cancel_drop_hovered = next_hovered
	cancel_drop_area.set_hovered(cancel_drop_hovered)


func _is_over_cancel_drop_area(global_position: Vector2) -> bool:
	if cancel_drop_area == null or not cancel_drop_area.visible:
		return false
	return _control_contains_global_point(cancel_drop_area, global_position)


func _release_dragging_card(card_index: int, global_position: Vector2) -> void:
	if cards_interaction_locked or dragging_card_index == -1:
		return
	var cancelled_by_drop_area: bool = _is_over_cancel_drop_area(global_position)
	arrow_layer.end_arrow()
	dragging_card_index = -1
	_reset_card_drag_state(card_index)
	_set_cancel_drop_visible(false)
	_clear_drag_target_highlight()
	if cancelled_by_drop_area:
		_restore_hover_after_cancel(global_position)
		return
	var character := _get_selected_character()
	if character == null:
		_restore_hover_after_cancel(global_position)
		return
	var card: CardData = _get_card_for_ui_index(character, card_index)
	if card == null:
		_restore_hover_after_cancel(global_position)
		return
	if _card_targets_ally(card):
		var ally_index: int = _player_index_at(global_position)
		if ally_index != -1:
			card_use_requested.emit(selected_character_index, card_index, -1, ally_index, _selected_difficulty())
			return
		_restore_hover_after_cancel(global_position)
		return
	if _card_targets_enemy(card):
		var enemy_index := _enemy_index_at(global_position)
		if enemy_index != -1:
			selected_enemy_index = enemy_index
			card_use_requested.emit(selected_character_index, card_index, enemy_index, -1, _selected_difficulty())
			return
		_restore_hover_after_cancel(global_position)
		return
	if card.target_type == CardData.TargetType.ALL_ENEMIES:
		card_use_requested.emit(selected_character_index, card_index, -1, -1, _selected_difficulty())
		return
	if card.is_general():
		card_use_requested.emit(selected_character_index, card_index, -1, -1, _selected_difficulty())
		return
	_restore_hover_after_cancel(global_position)


func _on_card_hover_changed(card_index: int, hovered: bool) -> void:
	if cards_interaction_locked or dragging_card_index != -1:
		return
	if hovered:
		if hovered_card_index == card_index:
			return
		hovered_card_index = card_index
	elif hovered_card_index == card_index:
		hovered_card_index = -1
	else:
		return
	_relayout_existing_cards()


func _relayout_existing_cards() -> void:
	_relayout_card_group(exclusive_cards, true)
	_relayout_card_group(general_cards, true)


func _relayout_card_group(parent: Control, animate: bool) -> void:
	var card_buttons: Array[CardButton] = []
	for child: Node in parent.get_children():
		if child is CardButton:
			var card_button: CardButton = child
			card_buttons.append(card_button)

	var count: int = card_buttons.size()
	for slot in count:
		_apply_card_arc_pose(parent, card_buttons[slot], slot, count, animate)


func _apply_card_arc_pose(parent: Control, card_button: CardButton, slot: int, count: int, animate: bool, entry_offset: Vector2 = Vector2.ZERO) -> void:
	var parent_size: Vector2 = parent.size
	if parent_size.x <= 1.0 or parent_size.y <= 1.0:
		parent_size = parent.custom_minimum_size

	var card_size: Vector2 = CARD_SIZE
	var pivot_offset: Vector2 = Vector2(card_size.x * 0.5, card_size.y * HAND_PIVOT_Y_OFFSET_FACTOR)
	var pivot_base_y: float = parent_size.y - (card_size.y - pivot_offset.y) - HAND_BOTTOM_PADDING
	var center_x: float = parent_size.x * 0.5
	if parent == general_cards:
		center_x -= GENERAL_HAND_LEFT_SHIFT
	var max_angle_degrees: float = _max_hand_angle_degrees_for_count(count)
	var max_angle: float = deg_to_rad(max_angle_degrees)
	var group_span: float = card_size.x * 0.32 * float(maxi(count - 1, 1))
	var available_span: float = minf(maxf(parent_size.x - card_size.x * 1.10, card_size.x * 0.30), group_span)
	var radius_by_width: float = available_span / maxf(2.0 * sin(max_angle), 0.01)
	var radius: float = clampf(radius_by_width, HAND_ARC_RADIUS_MIN, HAND_ARC_RADIUS_MAX)
	var start_angle: float = -max_angle
	var angle_step: float = 0.0 if count <= 1 else (max_angle * 2.0) / float(count - 1)
	var angle: float = 0.0 if count <= 1 else start_angle + angle_step * float(slot)

	var pivot_x: float = center_x + sin(angle) * radius
	var pivot_y: float = pivot_base_y + (1.0 - cos(angle)) * radius
	var rotation_degrees_value: float = rad_to_deg(angle)
	var any_dragging: bool = dragging_card_index != -1

	var hovered_slot: int = -1
	if hovered_card_index != -1 and not any_dragging:
		hovered_slot = _find_slot_for_hovered_card(parent)

	if hovered_slot >= 0 and not any_dragging:
		var distance: int = abs(slot - hovered_slot)
		var direction: float = -1.0 if slot < hovered_slot else 1.0
		if slot == hovered_slot:
			rotation_degrees_value *= 0.22
		elif distance == 1:
			pivot_x += direction * HAND_HOVER_NEIGHBOR_PUSH
			rotation_degrees_value *= 0.65
		elif distance == 2:
			pivot_x += direction * HAND_HOVER_SECONDARY_PUSH

	var scale_value: Vector2 = Vector2.ONE
	var z_index_value: int = slot
	if card_button.card_index == hovered_card_index and not any_dragging:
		pivot_y -= HAND_HOVER_LIFT
		scale_value = Vector2(1.10, 1.10)
		rotation_degrees_value = 0.0
		z_index_value = HOVERED_HAND_Z_INDEX

	var top_left: Vector2 = _convert_pivot_to_top_left(Vector2(pivot_x, pivot_y), pivot_offset, rotation_degrees_value, scale_value)
	if animate and entry_offset != Vector2.ZERO:
		card_button.set_hand_pose(top_left + entry_offset, rotation_degrees_value + 7.0, scale_value * 0.96, z_index_value, false)
		card_button.set_hand_pose(top_left, rotation_degrees_value, scale_value, z_index_value, true, 0.26, float(slot) * 0.035)
	else:
		card_button.set_hand_pose(top_left, rotation_degrees_value, scale_value, z_index_value, animate)
	card_button.set_focus_state(card_button.card_index == hovered_card_index, hovered_card_index != -1 and card_button.card_index != hovered_card_index and dragging_card_index == -1)


func _max_hand_angle_degrees_for_count(count: int) -> float:
	if count <= 1:
		return 0.0
	if count == 2:
		return 4.0
	if count == 3:
		return 6.5
	if count == 4:
		return 9.0
	if count == 5:
		return 11.0
	return minf(14.0, 11.0 + float(count - 5) * 1.0)


func _find_slot_for_hovered_card(parent: Control) -> int:
	var slot: int = 0
	for child: Node in parent.get_children():
		if child is CardButton:
			var card_button: CardButton = child
			if card_button.card_index == hovered_card_index:
				return slot
			slot += 1
	return -1


func _convert_pivot_to_top_left(pivot_position: Vector2, pivot_offset: Vector2, rotation_degrees_value: float, scale_value: Vector2) -> Vector2:
	var uniform_scale: float = (scale_value.x + scale_value.y) * 0.5
	var scaled_pivot: Vector2 = pivot_offset * uniform_scale
	var rotated_pivot: Vector2 = scaled_pivot.rotated(deg_to_rad(rotation_degrees_value))
	return pivot_position - rotated_pivot


func _enemy_index_at(global_position: Vector2) -> int:
	return battlefield_controller.enemy_index_at(global_position)


func _player_index_at(global_position: Vector2) -> int:
	return battlefield_controller.player_index_at(global_position)


func _update_drag_target_highlight(global_position: Vector2) -> void:
	var character: CharacterData = _get_selected_character()
	if character == null or dragging_card_index == -1:
		_clear_drag_target_highlight()
		return
	var card: CardData = _get_card_for_ui_index(character, dragging_card_index)
	if card == null:
		_clear_drag_target_highlight()
		return

	var next_player_index: int = -1
	var next_enemy_index: int = -1
	if _card_targets_ally(card):
		next_player_index = _player_index_at(global_position)
	elif _card_targets_enemy(card):
		next_enemy_index = _enemy_index_at(global_position)

	if next_player_index == hovered_player_target_index and next_enemy_index == hovered_enemy_target_index:
		return
	hovered_player_target_index = next_player_index
	hovered_enemy_target_index = next_enemy_index
	_refresh_battlefield()


func _clear_drag_target_highlight() -> void:
	if hovered_player_target_index == -1 and hovered_enemy_target_index == -1:
		return
	hovered_player_target_index = -1
	hovered_enemy_target_index = -1
	_refresh_battlefield()


func _card_targets_enemy(card: CardData) -> bool:
	return card.target_type == CardData.TargetType.SINGLE_ENEMY


func _card_targets_ally(card: CardData) -> bool:
	return card.card_type == CardData.CardType.DEFENSE


func _select_character(index: int) -> void:
	if index < 0 or index >= state.player_team.size():
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


func _select_enemy(index: int) -> void:
	if index < 0 or index >= state.enemy_team.size():
		return
	if not state.enemy_team[index].is_alive():
		return
	selected_enemy_index = index
	showing_enemy_info = true
	_refresh_status()
	_refresh_battlefield()


func _refresh_info_hint() -> void:
	if selected_hint == null or state == null:
		return
	if showing_enemy_info and selected_enemy_index >= 0 and selected_enemy_index < state.enemy_team.size():
		var enemy: EnemyData = state.enemy_team[selected_enemy_index]
		selected_hint.text = tr("INFO_ENEMY_FORMAT").replace("\\n", "\n") % [
			tr(enemy.display_name),
			_attribute_text(enemy.attribute),
			enemy.get_basic_attack_damage(),
			tr("INFO_NO_SKILL")
		]
		return

	var character: CharacterData = _get_selected_character()
	if character == null:
		selected_hint.text = ""
		return
	selected_hint.text = tr("INFO_PLAYER_FORMAT").replace("\\n", "\n") % [
		tr(character.display_name),
		_attribute_text(character.attribute),
		tr("STATUS_ACTED") if character.has_acted else tr("STATUS_READY"),
		_passive_text(character.attribute)
	]


func _passive_text(attribute: String) -> String:
	match attribute:
		"拼音":
			return tr("PASSIVE_PINYIN")
		"词汇":
			return tr("PASSIVE_VOCABULARY")
		"文化":
			return tr("PASSIVE_CULTURE")
		_:
			return tr("PASSIVE_NONE")


func _attribute_text(attribute: String) -> String:
	match attribute:
		"拼音":
			return tr("ATTRIBUTE_PINYIN")
		"词汇":
			return tr("ATTRIBUTE_VOCABULARY")
		"文化":
			return tr("ATTRIBUTE_CULTURE")
		_:
			return attribute


func _toggle_shop_panel() -> void:
	if shop_panel == null:
		return
	shop_panel.toggle()
	if shop_panel.visible:
		_refresh_shop_panel()


func _refresh_shop_panel() -> void:
	if shop_panel == null or state == null:
		return
	shop_panel.refresh(state.new_toefl, state.shop_offer_cards, state.ap)


func _buy_shop_card(offer_index: int) -> void:
	if state == null:
		return
	shop_buy_requested.emit(offer_index, selected_character_index)


func _get_selected_character() -> CharacterData:
	if state == null:
		return null
	if selected_character_index < 0 or selected_character_index >= state.player_team.size():
		return null
	return state.player_team[selected_character_index]


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


func _first_alive_enemy_index() -> int:
	for i in state.enemy_team.size():
		if state.enemy_team[i].is_alive():
			return i
	return -1


func _select_next_ready_character_if_needed() -> void:
	if state.phase != BattleState.Phase.PLAYER_TURN:
		return
	if selected_character_index >= 0 and selected_character_index < state.player_team.size():
		var selected := state.player_team[selected_character_index]
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


func _selected_difficulty() -> String:
	return "easy"


func _style(color: Color, radius: int, border_width: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.corner_radius_top_left = radius
	style.corner_radius_top_right = radius
	style.corner_radius_bottom_left = radius
	style.corner_radius_bottom_right = radius
	style.border_width_left = border_width
	style.border_width_right = border_width
	style.border_width_top = border_width
	style.border_width_bottom = border_width
	style.border_color = Color(0.13, 0.10, 0.08)
	style.shadow_color = Color(0, 0, 0, 0.20)
	style.shadow_size = 5
	return style


func _clear_children(node: Node) -> void:
	for child: Node in node.get_children():
		node.remove_child(child)
		child.queue_free()
