extends Control
## Displays player and enemy standees using editor-owned slot nodes.
class_name BattlefieldView

signal character_selected(character_index: int)
signal enemy_selected(enemy_index: int)

const CHARACTER_STANDEE_SCENE: PackedScene = preload("res://scenes/ui/CharacterStandee.tscn")
const ENEMY_STANDEE_SCENE: PackedScene = preload("res://scenes/ui/EnemyStandee.tscn")
const ENEMY_BASE_Z_INDEX: int = 100

var state: BattleState
var host: Control
var player_standees: Dictionary = {}
var enemy_standees: Dictionary = {}

@onready var player_layer: Control = $PlayerLayer
@onready var enemy_layer: Control = $EnemyLayer
@onready var player_top_slot: Control = $Slots/PlayerSlots/PlayerTopSlot
@onready var player_middle_slot: Control = $Slots/PlayerSlots/PlayerMiddleSlot
@onready var player_bottom_slot: Control = $Slots/PlayerSlots/PlayerBottomSlot
@onready var enemy_one_slots: Control = $Slots/EnemySlots/EnemyOneSlots
@onready var enemy_two_slots: Control = $Slots/EnemySlots/EnemyTwoSlots
@onready var enemy_many_slots: Control = $Slots/EnemySlots/EnemyManySlots


## Stores the tween host used by selection animations.
func setup(host_control: Control) -> void:
	host = host_control


## Rebuilds all standees from the current battle state.
func refresh_view(
	new_state: BattleState,
	selected_character_index: int,
	previous_character_index: int,
	selection_transition_pending: bool,
	selected_enemy_index: int,
	showing_enemy_info: bool,
	hovered_player_target_index: int,
	hovered_enemy_target_index: int
) -> void:
	state = new_state
	_clear_children(player_layer)
	_clear_children(enemy_layer)
	player_standees.clear()
	enemy_standees.clear()

	_refresh_players(
		selected_character_index,
		previous_character_index,
		selection_transition_pending,
		hovered_player_target_index
	)
	_refresh_enemies(selected_enemy_index, showing_enemy_info, hovered_enemy_target_index)


## Returns the player index under a global point, or -1 when none is hit.
func player_index_at(mouse_global_position: Vector2) -> int:
	if state == null:
		return -1
	for player_index: Variant in player_standees:
		var index: int = int(player_index)
		var standee: CharacterStandee = player_standees[player_index] as CharacterStandee
		if standee != null and state.player_team[index].is_alive() and _control_contains_global_point(standee, mouse_global_position):
			return index
	return -1


## Returns the enemy index under a global point, or -1 when none is hit.
func enemy_index_at(mouse_global_position: Vector2) -> int:
	if state == null:
		return -1
	for enemy_index: Variant in enemy_standees:
		var index: int = int(enemy_index)
		var standee: EnemyStandee = enemy_standees[enemy_index] as EnemyStandee
		if standee != null and state.enemy_team[index].is_alive() and _control_contains_global_point(standee, mouse_global_position):
			return index
	return -1


## Creates player standees at the editor-owned player slot nodes.
func _refresh_players(
	selected_character_index: int,
	previous_character_index: int,
	selection_transition_pending: bool,
	hovered_player_target_index: int
) -> void:
	var player_slots: Array[Control] = _player_slots_for_count(state.player_team.size())
	for i in state.player_team.size():
		if i >= player_slots.size():
			break
		var standee: CharacterStandee = CHARACTER_STANDEE_SCENE.instantiate() as CharacterStandee
		player_layer.add_child(standee)
		standee.standee_selected.connect(func(index: int) -> void: character_selected.emit(index))
		standee.setup(state.player_team[i], i, i == selected_character_index, i == hovered_player_target_index)

		var base_position: Vector2 = player_slots[i].position
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
		if start_position != target_position and host != null:
			var standee_tween: Tween = host.create_tween()
			standee_tween.set_ease(Tween.EASE_OUT)
			standee_tween.set_trans(Tween.TRANS_CUBIC)
			standee_tween.tween_property(standee, "position", target_position, 0.18)


## Chooses the visible player slots for the current party size.
func _player_slots_for_count(count: int) -> Array[Control]:
	match count:
		1:
			return [player_top_slot]
		2:
			return [player_top_slot, player_bottom_slot]
		_:
			return [player_top_slot, player_middle_slot, player_bottom_slot]


## Creates enemy standees at the editor-owned enemy slot nodes.
func _refresh_enemies(
	selected_enemy_index: int,
	showing_enemy_info: bool,
	hovered_enemy_target_index: int
) -> void:
	var alive_enemy_indices: Array[int] = []
	for i in state.enemy_team.size():
		if state.enemy_team[i].is_alive():
			alive_enemy_indices.append(i)

	var visible_enemy_count: int = mini(alive_enemy_indices.size(), 8)
	var enemy_slots: Array[Control] = _enemy_slots_for_count(visible_enemy_count)
	for slot in visible_enemy_count:
		if slot >= enemy_slots.size():
			break
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
		enemy_standee.position = enemy_slots[slot].position
		enemy_standee.size = enemy_standee.custom_minimum_size
		enemy_standee.scale = Vector2.ONE
		enemy_standee.z_index = ENEMY_BASE_Z_INDEX + maxi(0, roundi(enemy_standee.position.y))
		enemy_standees[enemy_index] = enemy_standee


## Chooses the enemy slot set that preserves special one- and two-enemy layouts.
func _enemy_slots_for_count(count: int) -> Array[Control]:
	if count <= 0:
		return []
	var slot_parent: Control = enemy_many_slots
	if count == 1:
		slot_parent = enemy_one_slots
	elif count == 2:
		slot_parent = enemy_two_slots

	var slots: Array[Control] = []
	for child: Node in slot_parent.get_children():
		if child is Control:
			slots.append(child as Control)
	return slots


## Checks whether a global point is inside a Control's canvas bounds.
func _control_contains_global_point(control: Control, mouse_global_position: Vector2) -> bool:
	var local_position: Vector2 = control.get_global_transform_with_canvas().affine_inverse() * mouse_global_position
	return Rect2(Vector2.ZERO, control.size).has_point(local_position)


## Clears dynamically spawned standees from a layer.
func _clear_children(node: Node) -> void:
	if node == null:
		return
	for child: Node in node.get_children():
		node.remove_child(child)
		child.queue_free()
