extends RefCounted
## 管理战场立绘实例、1～8 敌人站位、选择动画和坐标命中检测。
class_name BattlefieldController

signal character_selected(character_index: int)
signal enemy_selected(enemy_index: int)

const CHARACTER_STANDEE_SCENE: PackedScene = preload("res://scenes/ui/CharacterStandee.tscn")
const ENEMY_STANDEE_SCENE: PackedScene = preload("res://scenes/ui/EnemyStandee.tscn")
const DEFAULT_FIELD_SIZE: Vector2 = Vector2(1228, 395)
const ENEMY_STANDEE_SIZE: Vector2 = Vector2(220, 210)
const ENEMY_BASE_Z_INDEX: int = 100

var host: Control
var battlefield: Control
var player_layer: Control
var enemy_layer: Control
var state: BattleState
var player_standees: Dictionary = {}
var enemy_standees: Dictionary = {}


func setup(host_control: Control, battlefield_control: Control, player_control: Control, enemy_control: Control) -> void:
	host = host_control
	battlefield = battlefield_control
	player_layer = player_control
	enemy_layer = enemy_control


func refresh(
	new_state: BattleState,
	selected_character_index: int,
	previous_character_index: int,
	selection_transition_pending: bool,
	selected_enemy_index: int,
	showing_enemy_info: bool,
	hovered_player_target_index: int,
	hovered_enemy_target_index: int
) -> void:
	# 每次刷新重建立绘，确保死亡敌人立即消失且高亮状态不会残留。
	state = new_state
	_clear_children(player_layer)
	_clear_children(enemy_layer)
	player_standees.clear()
	enemy_standees.clear()

	var field_size: Vector2 = battlefield.size
	if field_size == Vector2.ZERO:
		field_size = DEFAULT_FIELD_SIZE

	_refresh_players(
		field_size,
		selected_character_index,
		previous_character_index,
		selection_transition_pending,
		hovered_player_target_index
	)
	_refresh_enemies(field_size, selected_enemy_index, showing_enemy_info, hovered_enemy_target_index)


func player_index_at(global_position: Vector2) -> int:
	if state == null:
		return -1
	for player_index: Variant in player_standees:
		var index: int = int(player_index)
		var standee: CharacterStandee = player_standees[player_index] as CharacterStandee
		if standee != null and state.player_team[index].is_alive() and _control_contains_global_point(standee, global_position):
			return index
	return -1


func enemy_index_at(global_position: Vector2) -> int:
	if state == null:
		return -1
	for enemy_index: Variant in enemy_standees:
		var index: int = int(enemy_index)
		var standee: EnemyStandee = enemy_standees[enemy_index] as EnemyStandee
		if standee != null and state.enemy_team[index].is_alive() and _control_contains_global_point(standee, global_position):
			return index
	return -1


func enemy_layout_for_count(count: int, field_size: Vector2) -> Array[Dictionary]:
	# 所有数量都保持原始尺寸，通过斜向错落和适度重叠容纳最多八只敌人。
	var layouts: Array[Dictionary] = []
	if count <= 0:
		return layouts

	var normalized_slots: Array[Vector2] = _enemy_slot_pattern(count)
	var enemy_region := Rect2(
		Vector2(field_size.x * 0.55, field_size.y * 0.02),
		Vector2(field_size.x * 0.43, field_size.y * 0.86)
	)

	for normalized_slot: Vector2 in normalized_slots:
		var center: Vector2 = enemy_region.position + enemy_region.size * normalized_slot
		layouts.append({
			"position": center - ENEMY_STANDEE_SIZE * 0.5,
			"scale": Vector2.ONE
		})
	return layouts


func _refresh_players(
	field_size: Vector2,
	selected_character_index: int,
	previous_character_index: int,
	selection_transition_pending: bool,
	hovered_player_target_index: int
) -> void:
	# 队伍人数少于三人时仍使用准备页对应的上/下站位。
	var player_positions: Array[Vector2] = _player_slot_positions(state.player_team.size(), field_size)
	for i in state.player_team.size():
		var standee: CharacterStandee = CHARACTER_STANDEE_SCENE.instantiate() as CharacterStandee
		player_layer.add_child(standee)
		standee.standee_selected.connect(func(index: int) -> void: character_selected.emit(index))
		standee.setup(state.player_team[i], i, i == selected_character_index, i == hovered_player_target_index)

		var base_position: Vector2 = player_positions[i]
		var target_position: Vector2 = base_position + (Vector2(0, -18) if i == selected_character_index else Vector2.ZERO)
		var start_position: Vector2 = target_position
		if selection_transition_pending:
			if i == selected_character_index:
				start_position = base_position + Vector2(0, 8)
			elif i == previous_character_index:
				start_position = base_position + Vector2(0, -18)

		standee.position = start_position
		standee.size = standee.custom_minimum_size
		player_standees[i] = standee
		if start_position != target_position:
			var standee_tween: Tween = host.create_tween()
			standee_tween.set_ease(Tween.EASE_OUT)
			standee_tween.set_trans(Tween.TRANS_CUBIC)
			standee_tween.tween_property(standee, "position", target_position, 0.18)


## 按当前队伍人数返回我方站位；两人时跳过中间位。
func _player_slot_positions(count: int, field_size: Vector2) -> Array[Vector2]:
	var top: Vector2 = Vector2(70, field_size.y * 0.08)
	var middle: Vector2 = Vector2(210, field_size.y * 0.27)
	var bottom: Vector2 = Vector2(70, field_size.y * 0.46)
	match count:
		1:
			return [top]
		2:
			return [top, bottom]
		_:
			return [top, middle, bottom]


func _refresh_enemies(
	field_size: Vector2,
	selected_enemy_index: int,
	showing_enemy_info: bool,
	hovered_enemy_target_index: int
) -> void:
	# 保留 enemy_team 原始索引，确保 UI 目标与战斗状态一致。
	var alive_enemy_indices: Array[int] = []
	for i in state.enemy_team.size():
		if state.enemy_team[i].is_alive():
			alive_enemy_indices.append(i)

	var visible_enemy_count: int = mini(alive_enemy_indices.size(), 8)
	var enemy_layouts: Array[Dictionary] = enemy_layout_for_count(visible_enemy_count, field_size)
	for slot in visible_enemy_count:
		var enemy_index: int = alive_enemy_indices[slot]
		var enemy_standee: EnemyStandee = ENEMY_STANDEE_SCENE.instantiate() as EnemyStandee
		enemy_layer.add_child(enemy_standee)
		enemy_standee.standee_selected.connect(func(index: int) -> void: enemy_selected.emit(index))
		enemy_standee.setup(
			state.enemy_team[enemy_index],
			enemy_index,
			enemy_index == selected_enemy_index and showing_enemy_info,
			enemy_index == hovered_enemy_target_index
		)
		var layout: Dictionary = enemy_layouts[slot]
		enemy_standee.position = layout["position"] as Vector2
		enemy_standee.size = enemy_standee.custom_minimum_size
		enemy_standee.scale = layout["scale"] as Vector2
		# 固定基础层级保证顶部单位也在背景遮罩前；纵向位置只负责单位间的纵深。
		enemy_standee.z_index = ENEMY_BASE_Z_INDEX + maxi(0, roundi(enemy_standee.position.y))
		enemy_standees[enemy_index] = enemy_standee


func _enemy_slot_pattern(count: int) -> Array[Vector2]:
	# 3～8 只使用累计槽位：新增敌人只占用右侧新位置，不改变已有相对站位。
	var mirrored_three: Array[Vector2] = [
		Vector2(0.52, 0.285),
		Vector2(0.08, 0.56),
		Vector2(0.50, 0.83)
	]
	var expansion_slots: Array[Vector2] = [
		Vector2(0.45, 0.51),
		Vector2(0.70, 0.82),
		Vector2(0.72, 0.29),
		Vector2(0.82, 0.52),
		Vector2(0.83, 0.80)
	]
	match count:
		1:
			return [Vector2(0.58, 0.50)]
		2:
			return [Vector2(0.38, 0.32), Vector2(0.70, 0.66)]
		_:
			var slots: Array[Vector2] = mirrored_three.duplicate()
			var additional_count: int = mini(maxi(count - 3, 0), expansion_slots.size())
			for i in additional_count:
				slots.append(expansion_slots[i])
			return slots


func _control_contains_global_point(control: Control, global_position: Vector2) -> bool:
	var local_position: Vector2 = control.get_global_transform_with_canvas().affine_inverse() * global_position
	return Rect2(Vector2.ZERO, control.size).has_point(local_position)


func _clear_children(node: Node) -> void:
	for child: Node in node.get_children():
		node.remove_child(child)
		child.queue_free()
