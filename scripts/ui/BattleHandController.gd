extends RefCounted
## 手牌显示控制器；只处理卡牌按钮创建、扇形布局、悬停、拖动视觉和通用卡消失动画。
class_name BattleHandController

signal card_clicked(card_index: int)
signal drag_started(card_index: int, global_position: Vector2)
signal drag_moved(global_position: Vector2)
signal drag_released(card_index: int, global_position: Vector2)

const CARD_SIZE: Vector2 = Vector2(144, 188)
const HOVERED_HAND_Z_INDEX: int = 100
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

var exclusive_cards: Control
var general_cards: Control
var dragging_card_index: int = -1
var hovered_card_index: int = -1
var hover_restore_time_left: float = 0.0
var interaction_locked: bool = false


## 绑定 BattleUI 场景中已经存在的两个手牌容器。
func setup(exclusive_parent: Control, general_parent: Control) -> void:
	exclusive_cards = exclusive_parent
	general_cards = general_parent


## 在取消拖动后的短时间内同步鼠标下方卡牌，修复悬停状态丢失。
func process_hover_restore(delta: float, global_mouse_position: Vector2) -> void:
	if dragging_card_index != -1:
		return
	if hover_restore_time_left <= 0.0:
		return
	hover_restore_time_left = maxf(0.0, hover_restore_time_left - delta)
	_sync_hovered_card_with_mouse(global_mouse_position)


## 根据当前角色和队伍通用牌重建两堆手牌。
func refresh(state: BattleState, character: CharacterData, selected_character_index: int, rendered_character_index: int) -> int:
	_clear_children(exclusive_cards)
	_clear_children(general_cards)
	if state == null or character == null:
		return rendered_character_index

	var exclusive: Array[int] = []
	var general: Array[int] = []
	for i in character.cards.size():
		if not character.cards[i].is_general():
			exclusive.append(i)
	for i in state.team_general_cards.size():
		general.append(encode_team_general_card_index(i))

	var should_slide_exclusive: bool = rendered_character_index != -1 and rendered_character_index != selected_character_index
	var entry_offset: Vector2 = Vector2(230, 28) if should_slide_exclusive else Vector2.ZERO
	_layout_card_fan(exclusive_cards, state, character, exclusive, should_slide_exclusive, entry_offset)
	_layout_card_fan(general_cards, state, character, general, false)
	return selected_character_index


## 设置卡牌交互锁；锁定时会清掉拖动和悬停视觉。
func set_interaction_locked(locked: bool) -> void:
	if interaction_locked == locked:
		return
	interaction_locked = locked
	if interaction_locked:
		cancel_current_interaction()
	else:
		hovered_card_index = -1
		_apply_card_interaction_lock_to_group(exclusive_cards)
		_apply_card_interaction_lock_to_group(general_cards)


## 取消当前手牌交互状态，不处理箭头、目标高亮等外部 UI。
func cancel_current_interaction() -> void:
	if dragging_card_index != -1:
		reset_card_drag_state(dragging_card_index)
		dragging_card_index = -1
	hover_restore_time_left = 0.0
	if hovered_card_index != -1:
		hovered_card_index = -1
		relayout_existing_cards()
	_apply_card_interaction_lock_to_group(exclusive_cards)
	_apply_card_interaction_lock_to_group(general_cards)


## 拖动结束后复位对应卡牌自身输入状态。
func finish_drag(card_index: int) -> void:
	dragging_card_index = -1
	reset_card_drag_state(card_index)


## 取消拖动后尝试恢复鼠标所在卡牌的悬停动画。
func restore_hover_after_cancel(global_position: Vector2) -> void:
	hover_restore_time_left = 0.36
	hovered_card_index = -1
	_sync_hovered_card_with_mouse(global_position)


## 返回 UI 编码索引对应的卡牌数据。
func get_card_for_ui_index(state: BattleState, character: CharacterData, card_index: int) -> CardData:
	if is_team_general_card_index(card_index):
		var team_card_index: int = decode_team_general_card_index(card_index)
		if state != null and team_card_index >= 0 and team_card_index < state.team_general_cards.size():
			return state.team_general_cards[team_card_index]
		return null
	if character != null and card_index >= 0 and card_index < character.cards.size():
		return character.cards[card_index]
	return null


## 把队伍通用牌索引编码成不会与角色专属牌冲突的负数。
func encode_team_general_card_index(team_card_index: int) -> int:
	return -team_card_index - TEAM_GENERAL_CARD_INDEX_OFFSET


## 判断一个 UI 索引是否指向队伍通用牌。
func is_team_general_card_index(card_index: int) -> bool:
	return card_index <= -TEAM_GENERAL_CARD_INDEX_OFFSET


## 从 UI 负数索引还原队伍通用牌数组索引。
func decode_team_general_card_index(card_index: int) -> int:
	return -card_index - TEAM_GENERAL_CARD_INDEX_OFFSET


## 通用卡使用成功前播放逐渐消失并上浮的粒子反馈。
func play_general_card_consume_animation(owner: Control, card_index: int) -> Signal:
	var completed: Signal = owner.get_tree().process_frame
	var card_button: CardButton = _find_card_button(general_cards, card_index)
	if card_button == null:
		return completed
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
		var particle_tween: Tween = card_button.create_tween()
		particle_tween.set_parallel(true)
		particle_tween.set_ease(Tween.EASE_OUT)
		particle_tween.set_trans(Tween.TRANS_CUBIC)
		particle_tween.tween_property(particle, "position", particle.position + drift, 0.34)
		particle_tween.tween_property(particle, "modulate:a", 0.0, 0.34)

	var card_tween: Tween = card_button.create_tween()
	card_tween.set_parallel(true)
	card_tween.set_ease(Tween.EASE_OUT)
	card_tween.set_trans(Tween.TRANS_CUBIC)
	card_tween.tween_property(card_button, "position", card_button.position + Vector2(0, -38), 0.34)
	card_tween.tween_property(card_button, "scale", card_button.scale * 0.92, 0.34)
	card_tween.tween_property(card_button, "modulate:a", 0.0, 0.34)
	return card_tween.finished


## 重排当前已存在的两组卡牌，不重新实例化。
func relayout_existing_cards() -> void:
	_relayout_card_group(exclusive_cards, true)
	_relayout_card_group(general_cards, true)


## 接收 CardButton 点击信号并转发给 BattleUI。
func _on_card_clicked(card_index: int) -> void:
	if interaction_locked:
		return
	card_clicked.emit(card_index)


## 接收 CardButton 拖动开始信号并切换手牌到拖动视觉状态。
func _on_card_drag_started(card_index: int, global_position: Vector2) -> void:
	if interaction_locked:
		reset_card_drag_state(card_index)
		return
	dragging_card_index = card_index
	hovered_card_index = -1
	relayout_existing_cards()
	drag_started.emit(card_index, global_position)


## 接收 CardButton 拖动移动信号并转发给 BattleUI。
func _on_card_drag_moved(global_position: Vector2) -> void:
	if interaction_locked:
		return
	drag_moved.emit(global_position)


## 接收 CardButton 拖动松开信号并交给 BattleUI 判断落点。
func _on_card_drag_released(card_index: int, global_position: Vector2) -> void:
	if interaction_locked:
		reset_card_drag_state(card_index)
		return
	drag_released.emit(card_index, global_position)


## 接收 CardButton 悬停变化并重排扇形手牌。
func _on_card_hover_changed(card_index: int, hovered: bool) -> void:
	if interaction_locked or dragging_card_index != -1:
		return
	if hovered:
		if hovered_card_index == card_index:
			return
		hovered_card_index = card_index
	elif hovered_card_index == card_index:
		hovered_card_index = -1
	else:
		return
	relayout_existing_cards()


## 在指定容器中按扇形创建卡牌按钮。
func _layout_card_fan(parent: Control, state: BattleState, character: CharacterData, indices: Array[int], animate: bool, entry_offset: Vector2 = Vector2.ZERO) -> void:
	var can_click: bool = state.phase == BattleState.Phase.PLAYER_TURN and character.is_alive() and not character.has_acted and not interaction_locked
	var count: int = indices.size()
	for slot in count:
		var card_index: int = indices[slot]
		var card_data: CardData = get_card_for_ui_index(state, character, card_index)
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
		card_button.set_interaction_locked(interaction_locked)
		_apply_card_arc_pose(parent, card_button, slot, count, animate, entry_offset)


## 仅重排某一组已经实例化的卡牌。
func _relayout_card_group(parent: Control, animate: bool) -> void:
	var card_buttons: Array[CardButton] = []
	for child: Node in parent.get_children():
		if child is CardButton:
			var card_button: CardButton = child
			card_buttons.append(card_button)

	var count: int = card_buttons.size()
	for slot in count:
		_apply_card_arc_pose(parent, card_buttons[slot], slot, count, animate)


## 计算单张卡牌在扇形手牌中的位置、旋转、缩放和层级。
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
	var hovered_slot: int = _find_slot_for_hovered_card(parent) if hovered_card_index != -1 and not any_dragging else -1

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


## 根据卡牌数量决定扇形角度，避免少量牌过散。
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


## 查找当前悬停卡牌在某一组手牌中的槽位。
func _find_slot_for_hovered_card(parent: Control) -> int:
	var slot: int = 0
	for child: Node in parent.get_children():
		if child is CardButton:
			var card_button: CardButton = child
			if card_button.card_index == hovered_card_index:
				return slot
			slot += 1
	return -1


## 将以旋转轴为中心的坐标转换成 Control 左上角坐标。
func _convert_pivot_to_top_left(pivot_position: Vector2, pivot_offset: Vector2, rotation_degrees_value: float, scale_value: Vector2) -> Vector2:
	var uniform_scale: float = (scale_value.x + scale_value.y) * 0.5
	var scaled_pivot: Vector2 = pivot_offset * uniform_scale
	var rotated_pivot: Vector2 = scaled_pivot.rotated(deg_to_rad(rotation_degrees_value))
	return pivot_position - rotated_pivot


## 将鼠标下方的卡牌设为悬停状态。
func _sync_hovered_card_with_mouse(global_position: Vector2) -> void:
	var next_hovered_card_index: int = _card_index_at_global_position(global_position)
	if next_hovered_card_index == hovered_card_index:
		return
	hovered_card_index = next_hovered_card_index
	relayout_existing_cards()


## 返回鼠标位置命中的最上层卡牌索引。
func _card_index_at_global_position(global_position: Vector2) -> int:
	var card_index: int = _card_index_at_global_position_in_group(general_cards, global_position)
	if card_index != -1:
		return card_index
	return _card_index_at_global_position_in_group(exclusive_cards, global_position)


## 在指定手牌组中从上到下查找鼠标命中的卡牌。
func _card_index_at_global_position_in_group(parent: Control, global_position: Vector2) -> int:
	if parent == null:
		return -1
	var children: Array[Node] = parent.get_children()
	for i in range(children.size() - 1, -1, -1):
		var child: Node = children[i]
		if child is CardButton:
			var card_button: CardButton = child
			if _control_contains_global_point(card_button, global_position):
				return card_button.card_index
	return -1


## 判断 Control 的本地矩形是否包含某个全局坐标。
func _control_contains_global_point(control: Control, global_position: Vector2) -> bool:
	var local_position: Vector2 = control.get_global_transform_with_canvas().affine_inverse() * global_position
	return Rect2(Vector2.ZERO, control.size).has_point(local_position)


## 在两组手牌中查找指定 UI 索引对应的 CardButton。
func _find_card_button(parent: Control, card_index: int) -> CardButton:
	if parent == null:
		return null
	for child: Node in parent.get_children():
		if child is CardButton:
			var card_button: CardButton = child
			if card_button.card_index == card_index:
				return card_button
	return null


## 重置指定卡牌的拖动输入状态。
func reset_card_drag_state(card_index: int) -> void:
	var card_button: CardButton = _find_card_button(exclusive_cards, card_index)
	if card_button == null:
		card_button = _find_card_button(general_cards, card_index)
	if card_button != null:
		card_button.reset_drag_state()


## 把交互锁同步给某一组已经存在的卡牌按钮。
func _apply_card_interaction_lock_to_group(parent: Control) -> void:
	if parent == null:
		return
	for child: Node in parent.get_children():
		if child is CardButton:
			var card_button: CardButton = child
			card_button.set_interaction_locked(interaction_locked)


## 清空一个容器的全部运行时卡牌节点。
func _clear_children(node: Node) -> void:
	if node == null:
		return
	for child: Node in node.get_children():
		node.remove_child(child)
		child.queue_free()
