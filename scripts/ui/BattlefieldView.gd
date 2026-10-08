extends Control
## Displays player and enemy standees using editor-owned slot nodes.
class_name BattlefieldView

signal character_selected(character_index: int)
signal enemy_selected(enemy_index: int)

const CHARACTER_STANDEE_SCENE: PackedScene = preload("res://scenes/ui/CharacterStandee.tscn")
const ENEMY_STANDEE_SCENE: PackedScene = preload("res://scenes/ui/EnemyStandee.tscn")
const ENEMY_BASE_Z_INDEX: int = 100

var state: BattleState
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


## Refreshes retained units; only replaced teams or defeated enemies remove nodes.
func refresh_view(
	new_state: BattleState,
	selected_character_index: int,
	selection_jump_pending: bool,
	selected_enemy_index: int,
	showing_enemy_info: bool,
	hovered_player_target_index: int,
	hovered_enemy_target_index: int
) -> void:
	state = new_state
	_prune_standees()

	_refresh_players(
		selected_character_index,
		selection_jump_pending,
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
		if standee != null and state.player_team[index].is_alive() and standee.contains_global_point(mouse_global_position):
			return index
	return -1


## Returns the enemy index under a global point, or -1 when none is hit.
func enemy_index_at(mouse_global_position: Vector2) -> int:
	if state == null:
		return -1
	for enemy_index: Variant in enemy_standees:
		var index: int = int(enemy_index)
		var standee: EnemyStandee = enemy_standees[enemy_index] as EnemyStandee
		if standee != null and state.enemy_team[index].is_alive() and standee.contains_global_point(mouse_global_position):
			return index
	return -1


## Updates retained player standees at the editor-owned slot nodes.
func _refresh_players(
	selected_character_index: int,
	selection_jump_pending: bool,
	hovered_player_target_index: int
) -> void:
	var player_slots: Array[Control] = _player_slots_for_count(state.player_team.size())
	for i in state.player_team.size():
		if i >= player_slots.size():
			break
		var standee: CharacterStandee = player_standees.get(i) as CharacterStandee
		if standee == null:
			standee = CHARACTER_STANDEE_SCENE.instantiate() as CharacterStandee
			player_layer.add_child(standee)
			standee.standee_selected.connect(func(index: int) -> void: character_selected.emit(index))
		standee.setup(state.player_team[i], i, i == selected_character_index, i == hovered_player_target_index)

		standee.position = player_slots[i].position
		standee.size = standee.custom_minimum_size
		player_standees[i] = standee
		if selection_jump_pending and i == selected_character_index:
			standee.play_selection_jump()


## Chooses the visible player slots for the current party size.
func _player_slots_for_count(count: int) -> Array[Control]:
	match count:
		1:
			return [player_top_slot]
		2:
			return [player_top_slot, player_bottom_slot]
		_:
			return [player_top_slot, player_middle_slot, player_bottom_slot]


## Updates retained enemy standees while preserving stable enemy-team indices.
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
		var enemy_standee: EnemyStandee = enemy_standees.get(enemy_index) as EnemyStandee
		if enemy_standee == null:
			enemy_standee = ENEMY_STANDEE_SCENE.instantiate() as EnemyStandee
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


## Removes stale identities on retry/wave changes without restarting surviving units.
func _prune_standees() -> void:
	for key: Variant in player_standees.keys():
		var index: int = int(key)
		var standee: CharacterStandee = player_standees[key] as CharacterStandee
		if index >= state.player_team.size() or standee.bound_character != state.player_team[index]:
			player_layer.remove_child(standee)
			standee.queue_free()
			player_standees.erase(key)
	for key: Variant in enemy_standees.keys():
		var index: int = int(key)
		var standee: EnemyStandee = enemy_standees[key] as EnemyStandee
		if index >= state.enemy_team.size() or standee.bound_enemy != state.enemy_team[index] or not state.enemy_team[index].is_alive():
			enemy_layer.remove_child(standee)
			standee.queue_free()
			enemy_standees.erase(key)


## Starts one or more player actions together and waits for the longest sequence.
func play_player_action(indices: Array[int], animation_name: StringName) -> void:
	var duration: float = 0.0
	for index in indices:
		var standee: CharacterStandee = player_standees.get(index) as CharacterStandee
		if standee != null:
			duration = maxf(duration, standee.play_action(animation_name))
	if duration > 0.0:
		await get_tree().create_timer(duration).timeout


## Plays a reserved enemy attack or support animation on its retained unit.
func play_enemy_action(index: int, is_attack: bool) -> void:
	var standee: EnemyStandee = enemy_standees.get(index) as EnemyStandee
	if standee != null:
		await standee.play_action(is_attack)
