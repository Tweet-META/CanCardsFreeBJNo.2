extends Control
## Manages the slide-up level preparation panel on the map.
class_name PreparationPanel

signal enter_level_requested(level: LevelData, selected_character_ids: Array[String], learning_goal_character_id: String)
signal preparation_changed()

const CHARACTER_SELECT_BUTTON_SCENE: PackedScene = preload("res://scenes/ui/CharacterSelectButton.tscn")

@export var panel_height: float = 345.0

var available_characters: Array[CharacterData] = []
var selected_character_ids: Array[String] = []
var learning_goal_character_id: String = ""
var pending_level: LevelData
var prep_tween: Tween
var opened: bool = false

@onready var dimmer: ColorRect = $Dimmer
@onready var panel: PanelContainer = $PrepPanel
@onready var level_title: Label = $PrepPanel/PrepContent/Header/LevelTitle
@onready var wave_label: Label = $PrepPanel/PrepContent/Header/WaveLabel
@onready var description_label: Label = $PrepPanel/PrepContent/Header/DescriptionLabel
@onready var slot_top_button: Button = $PrepPanel/PrepContent/MainRow/PartyCenter/PartyColumn/SlotRow/SlotTop
@onready var slot_middle_button: Button = $PrepPanel/PrepContent/MainRow/PartyCenter/PartyColumn/SlotRow/SlotMiddle
@onready var slot_bottom_button: Button = $PrepPanel/PrepContent/MainRow/PartyCenter/PartyColumn/SlotRow/SlotBottom
@onready var character_list: HBoxContainer = $PrepPanel/PrepContent/MainRow/PartyCenter/PartyColumn/CharacterList
@onready var learning_goal_button: LearningGoalButton = $PrepPanel/PrepContent/MainRow/LearningGoalButton
@onready var back_button: Button = $PrepPanel/PrepContent/Footer/PrepBackButton
@onready var start_button: Button = $PrepPanel/PrepContent/Footer/PrepStartButton
@onready var learning_goal_drawer: LearningGoalDrawer = $LearningGoalDrawer


## Connects local controls and starts closed.
func _ready() -> void:
	slot_top_button.pressed.connect(_remove_selected_slot.bind(0))
	slot_middle_button.pressed.connect(_remove_selected_slot.bind(1))
	slot_bottom_button.pressed.connect(_remove_selected_slot.bind(2))
	dimmer.gui_input.connect(_on_dimmer_input)
	learning_goal_button.pressed.connect(_toggle_learning_goal_drawer)
	learning_goal_drawer.goal_source_selected.connect(_select_learning_goal_source)
	learning_goal_drawer.visibility_changed.connect(func() -> void: preparation_changed.emit())
	back_button.pressed.connect(close.bind(true))
	start_button.pressed.connect(_confirm_enter_level)
	LanguageManager.language_changed.connect(_on_language_changed)
	close(false)


## Opens the panel for one level and resets the selected party.
func open_for_level(level: LevelData, characters: Array[CharacterData]) -> void:
	pending_level = level
	available_characters = characters
	selected_character_ids.clear()
	learning_goal_character_id = ""
	_refresh_text()
	_refresh_character_buttons()
	_refresh_slots()
	_refresh_learning_goal()
	_set_open(true, true)


## Closes the panel.
func close(animated: bool = true) -> void:
	learning_goal_drawer.close(false)
	_set_open(false, animated)


## Refreshes translated labels when the active language changes.
func _on_language_changed(_locale: String) -> void:
	if pending_level == null:
		return
	_refresh_text()
	_refresh_character_buttons()
	_refresh_slots()
	_refresh_learning_goal()


## Updates the level title, wave count, and description.
func _refresh_text() -> void:
	if pending_level == null:
		return
	level_title.text = tr("PREP_LEVEL_FORMAT") % pending_level.marker_text
	wave_label.text = tr("PREP_WAVE_COUNT") % pending_level.waves.size()
	description_label.text = tr(pending_level.description)
	if pending_level.requires_learning_goal:
		description_label.text += "\n" + tr("PREP_TUTORIAL_GOAL_REQUIRED")


## Rebuilds the selectable character row from reusable button scenes.
func _refresh_character_buttons() -> void:
	for child: Node in character_list.get_children():
		child.queue_free()

	for character: CharacterData in available_characters:
		var character_id: String = character.id
		var button: CharacterSelectButton = CHARACTER_SELECT_BUTTON_SCENE.instantiate() as CharacterSelectButton
		character_list.add_child(button)
		var is_selected: bool = character_id in selected_character_ids
		var is_locked: bool = selected_character_ids.size() >= 3 and not is_selected
		button.setup(character, is_selected, is_locked)
		button.character_toggled.connect(_toggle_character)


## Toggles a character in the selected party, respecting the three-character cap.
func _toggle_character(character_id: String) -> void:
	if character_id in selected_character_ids:
		selected_character_ids.erase(character_id)
	elif selected_character_ids.size() < 3:
		selected_character_ids.append(character_id)
	_refresh_character_buttons()
	_refresh_slots()
	preparation_changed.emit()


## Refreshes the three battle-position slots.
func _refresh_slots() -> void:
	var slot_buttons: Array[Button] = [slot_top_button, slot_middle_button, slot_bottom_button]
	for slot_index in range(slot_buttons.size()):
		var button: Button = slot_buttons[slot_index]
		var selected_index: int = _selected_index_for_slot(slot_index)
		var should_show_empty_middle: bool = selected_character_ids.is_empty() and slot_index == 1
		button.visible = selected_index != -1 or should_show_empty_middle
		button.disabled = selected_index == -1
		button.text = tr("PREP_EMPTY_SLOT") if selected_index == -1 else _character_name_for_id(selected_character_ids[selected_index])
	_update_start_button()


## Maps the visible slot to the selected party index.
func _selected_index_for_slot(slot_index: int) -> int:
	match selected_character_ids.size():
		0:
			return -1
		1:
			return 0 if slot_index == 0 else -1
		2:
			if slot_index == 0:
				return 0
			if slot_index == 2:
				return 1
			return -1
		_:
			return slot_index if slot_index < selected_character_ids.size() else -1


## Removes the selected character assigned to a visible slot.
func _remove_selected_slot(slot_index: int) -> void:
	var selected_index: int = _selected_index_for_slot(slot_index)
	if selected_index < 0 or selected_index >= selected_character_ids.size():
		return
	selected_character_ids.remove_at(selected_index)
	_refresh_character_buttons()
	_refresh_slots()
	preparation_changed.emit()


## Finds a localized character name from the available character list.
func _character_name_for_id(character_id: String) -> String:
	for character: CharacterData in available_characters:
		if character.id == character_id:
			return tr(character.display_name)
	return character_id


## Opens or closes the learning-goal drawer without changing the party.
func _toggle_learning_goal_drawer() -> void:
	if learning_goal_drawer.is_open():
		learning_goal_drawer.close(true)
	else:
		learning_goal_drawer.open_with(available_characters, learning_goal_character_id)
	preparation_changed.emit()


## Stores the optional unlocked character chosen as this battle's goal source.
func _select_learning_goal_source(character_id: String) -> void:
	learning_goal_character_id = character_id
	_refresh_learning_goal()
	_update_start_button()
	preparation_changed.emit()


## Requires a goal only in the level explicitly configured as the first tutorial.
func _update_start_button() -> void:
	var missing_goal: bool = pending_level != null and pending_level.requires_learning_goal and learning_goal_character_id.is_empty()
	start_button.disabled = selected_character_ids.is_empty() or missing_goal


## Refreshes the collapsed goal selector from the current source character.
func _refresh_learning_goal() -> void:
	var character: CharacterData = _character_for_id(learning_goal_character_id)
	var goal: LearningGoalData = LearningGoalDatabase.create_goal_for_character(character)
	learning_goal_button.setup(character, goal)


## Finds an unlocked character by stable ID.
func _character_for_id(character_id: String) -> CharacterData:
	for character: CharacterData in available_characters:
		if character.id == character_id:
			return character
	return null


## Closes the panel when the dimmed area is clicked.
func _on_dimmer_input(event: InputEvent) -> void:
	var mouse_event: InputEventMouseButton = event as InputEventMouseButton
	if mouse_event == null:
		return
	if mouse_event.button_index == MOUSE_BUTTON_LEFT and mouse_event.pressed:
		close(true)
		accept_event()


## Emits the selected party and optional goal source to the map scene.
func _confirm_enter_level() -> void:
	if pending_level == null or selected_character_ids.is_empty():
		return
	if pending_level.requires_learning_goal and learning_goal_character_id.is_empty():
		return
	enter_level_requested.emit(pending_level, selected_character_ids.duplicate(), learning_goal_character_id)


## Opens or closes the slide-up panel.
func _set_open(open: bool, animated: bool) -> void:
	opened = open
	if prep_tween != null:
		prep_tween.kill()
	var was_visible: bool = visible
	visible = true
	mouse_filter = Control.MOUSE_FILTER_STOP if open else Control.MOUSE_FILTER_IGNORE
	preparation_changed.emit()

	var target_top: float = -panel_height if open else 0.0
	var target_bottom: float = 0.0 if open else panel_height
	if not animated:
		panel.offset_top = target_top
		panel.offset_bottom = target_bottom
		visible = open
		return

	if open and not was_visible:
		panel.offset_top = 0.0
		panel.offset_bottom = panel_height
	prep_tween = create_tween()
	prep_tween.set_ease(Tween.EASE_OUT)
	prep_tween.set_trans(Tween.TRANS_CUBIC)
	prep_tween.tween_property(panel, "offset_top", target_top, 0.22)
	prep_tween.parallel().tween_property(panel, "offset_bottom", target_bottom, 0.22)
	if not open:
		prep_tween.finished.connect(func() -> void: visible = false)
