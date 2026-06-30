extends Control
## Manages the slide-up level preparation panel on the map.
class_name PreparationPanel

signal enter_level_requested(level: LevelData, selected_character_ids: Array[String])

const PAPER: Color = Color(0.86, 0.78, 0.64, 0.96)
const INK: Color = Color(0.12, 0.10, 0.08)
const CHARACTER_SELECT_BUTTON_SCENE: PackedScene = preload("res://scenes/ui/CharacterSelectButton.tscn")

@export var panel_height: float = 345.0

var available_characters: Array[CharacterData] = []
var selected_character_ids: Array[String] = []
var pending_level: LevelData
var prep_tween: Tween

@onready var dimmer: ColorRect = $Dimmer
@onready var panel: PanelContainer = $PrepPanel
@onready var level_title: Label = $PrepPanel/PrepContent/Header/LevelTitle
@onready var wave_label: Label = $PrepPanel/PrepContent/Header/WaveLabel
@onready var description_label: Label = $PrepPanel/PrepContent/Header/DescriptionLabel
@onready var slot_top_button: Button = $PrepPanel/PrepContent/SlotRow/SlotTop
@onready var slot_middle_button: Button = $PrepPanel/PrepContent/SlotRow/SlotMiddle
@onready var slot_bottom_button: Button = $PrepPanel/PrepContent/SlotRow/SlotBottom
@onready var character_list: HBoxContainer = $PrepPanel/PrepContent/CharacterList
@onready var back_button: Button = $PrepPanel/PrepContent/Footer/PrepBackButton
@onready var start_button: Button = $PrepPanel/PrepContent/Footer/PrepStartButton


## Connects local controls and starts closed.
func _ready() -> void:
	slot_top_button.pressed.connect(_remove_selected_slot.bind(0))
	slot_middle_button.pressed.connect(_remove_selected_slot.bind(1))
	slot_bottom_button.pressed.connect(_remove_selected_slot.bind(2))
	dimmer.gui_input.connect(_on_dimmer_input)
	back_button.pressed.connect(close.bind(true))
	start_button.pressed.connect(_confirm_enter_level)
	LanguageManager.language_changed.connect(_on_language_changed)
	_apply_styles()
	close(false)


## Opens the panel for one level and resets the selected party.
func open_for_level(level: LevelData, characters: Array[CharacterData]) -> void:
	pending_level = level
	available_characters = characters
	selected_character_ids.clear()
	_refresh_text()
	_refresh_character_buttons()
	_refresh_slots()
	_set_open(true, true)


## Closes the panel.
func close(animated: bool = true) -> void:
	_set_open(false, animated)


## Refreshes translated labels when the active language changes.
func _on_language_changed(_locale: String) -> void:
	if pending_level == null:
		return
	_refresh_text()
	_refresh_character_buttons()
	_refresh_slots()


## Updates the level title, wave count, and description.
func _refresh_text() -> void:
	if pending_level == null:
		return
	level_title.text = tr("PREP_LEVEL_FORMAT") % pending_level.marker_text
	wave_label.text = tr("PREP_WAVE_COUNT") % pending_level.waves.size()
	description_label.text = tr(pending_level.description)


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
		button.add_theme_stylebox_override("normal", _style(Color(0.90, 0.82, 0.68, 0.96), 14, 3))
		button.add_theme_stylebox_override("hover", _style(Color(0.98, 0.88, 0.62, 0.98), 14, 3))
	start_button.disabled = selected_character_ids.is_empty()


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


## Finds a localized character name from the available character list.
func _character_name_for_id(character_id: String) -> String:
	for character: CharacterData in available_characters:
		if character.id == character_id:
			return tr(character.display_name)
	return character_id


## Closes the panel when the dimmed area is clicked.
func _on_dimmer_input(event: InputEvent) -> void:
	var mouse_event: InputEventMouseButton = event as InputEventMouseButton
	if mouse_event == null:
		return
	if mouse_event.button_index == MOUSE_BUTTON_LEFT and mouse_event.pressed:
		close(true)
		accept_event()


## Emits the selected party to the map scene.
func _confirm_enter_level() -> void:
	if pending_level == null or selected_character_ids.is_empty():
		return
	enter_level_requested.emit(pending_level, selected_character_ids.duplicate())


## Opens or closes the slide-up panel.
func _set_open(open: bool, animated: bool) -> void:
	if prep_tween != null:
		prep_tween.kill()
	var was_visible: bool = visible
	visible = true
	mouse_filter = Control.MOUSE_FILTER_STOP if open else Control.MOUSE_FILTER_IGNORE

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


## Applies local paper-style button and panel overrides.
func _apply_styles() -> void:
	panel.add_theme_stylebox_override("panel", _style(Color(0.86, 0.78, 0.64, 0.98), 18, 4))
	back_button.add_theme_stylebox_override("normal", _style(PAPER, 12, 3))
	start_button.add_theme_stylebox_override("normal", _style(Color(0.91, 0.74, 0.35, 1.0), 12, 3))
	back_button.add_theme_color_override("font_color", INK)
	start_button.add_theme_color_override("font_color", INK)


## Creates one flat paper stylebox.
func _style(color: Color, radius: int, border_width: int) -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
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
	style.shadow_color = Color(0, 0, 0, 0.24)
	style.shadow_size = 6
	return style
