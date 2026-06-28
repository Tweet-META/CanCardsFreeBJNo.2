extends Control
## Main-menu save-slot picker for starting, loading, and deleting saves.
class_name SaveSlotPanel

signal enter_game_requested()

enum Mode {
	START,
	LOAD
}

const PAPER: Color = Color(0.86, 0.78, 0.64, 0.98)
const INK: Color = Color(0.12, 0.10, 0.08)

@onready var panel: PanelContainer = $Panel
@onready var title_label: Label = $Panel/Content/TitleLabel
@onready var subtitle_label: Label = $Panel/Content/SubtitleLabel
@onready var slot_1_summary: Label = $Panel/Content/SlotList/Slot1/Summary
@onready var slot_1_select_button: Button = $Panel/Content/SlotList/Slot1/SelectButton
@onready var slot_1_delete_button: Button = $Panel/Content/SlotList/Slot1/DeleteButton
@onready var slot_2_summary: Label = $Panel/Content/SlotList/Slot2/Summary
@onready var slot_2_select_button: Button = $Panel/Content/SlotList/Slot2/SelectButton
@onready var slot_2_delete_button: Button = $Panel/Content/SlotList/Slot2/DeleteButton
@onready var slot_3_summary: Label = $Panel/Content/SlotList/Slot3/Summary
@onready var slot_3_select_button: Button = $Panel/Content/SlotList/Slot3/SelectButton
@onready var slot_3_delete_button: Button = $Panel/Content/SlotList/Slot3/DeleteButton
@onready var close_button: Button = $Panel/Content/CloseButton
@onready var delete_confirm_dialog: ConfirmationDialog = $DeleteConfirmDialog

var mode: Mode = Mode.START
var pending_delete_slot: int = 0
var summary_labels: Array[Label] = []
var select_buttons: Array[Button] = []
var delete_buttons: Array[Button] = []


## Connects panel controls and applies the paper UI style.
func _ready() -> void:
	summary_labels = [slot_1_summary, slot_2_summary, slot_3_summary]
	select_buttons = [slot_1_select_button, slot_2_select_button, slot_3_select_button]
	delete_buttons = [slot_1_delete_button, slot_2_delete_button, slot_3_delete_button]

	for index in SaveManager.SLOT_COUNT:
		var slot_index: int = index + 1
		select_buttons[index].pressed.connect(_on_select_slot.bind(slot_index))
		delete_buttons[index].pressed.connect(_request_delete_slot.bind(slot_index))

	close_button.pressed.connect(close)
	delete_confirm_dialog.confirmed.connect(_confirm_delete_slot)
	LanguageManager.language_changed.connect(func(_locale: String) -> void: _refresh())
	SaveManager.slot_list_changed.connect(_refresh)
	_apply_styles()
	close()


## Opens the picker for choosing an empty slot and starting a new game.
func open_for_start() -> void:
	mode = Mode.START
	_refresh()
	show()


## Opens the picker for loading or deleting an existing save.
func open_for_load() -> void:
	mode = Mode.LOAD
	_refresh()
	show()


## Closes the save picker.
func close() -> void:
	hide()
	pending_delete_slot = 0


## Refreshes all slot summaries and available actions.
func _refresh() -> void:
	title_label.text = tr("SAVE_START_TITLE") if mode == Mode.START else tr("SAVE_LOAD_TITLE")
	subtitle_label.text = tr("SAVE_START_SUBTITLE") if mode == Mode.START else tr("SAVE_LOAD_SUBTITLE")
	close_button.text = tr("COMMON_CANCEL")
	delete_confirm_dialog.title = tr("SAVE_DELETE_TITLE")
	delete_confirm_dialog.dialog_text = tr("SAVE_DELETE_CONFIRM") % pending_delete_slot

	for index in SaveManager.SLOT_COUNT:
		var slot_index: int = index + 1
		var summary: Dictionary = SaveManager.get_slot_summary(slot_index)
		var exists: bool = bool(summary.get("exists", false))
		summary_labels[index].text = _format_summary(summary)
		select_buttons[index].text = _select_button_text(exists)
		select_buttons[index].disabled = exists if mode == Mode.START else not exists
		delete_buttons[index].text = tr("SAVE_DELETE")
		delete_buttons[index].visible = mode == Mode.LOAD
		delete_buttons[index].disabled = not exists


## Formats a compact one-line summary for a slot.
func _format_summary(summary: Dictionary) -> String:
	var slot_index: int = int(summary.get("slot", 0))
	if not bool(summary.get("exists", false)):
		return tr("SAVE_EMPTY_SLOT") % slot_index
	return tr("SAVE_SLOT_SUMMARY") % [
		slot_index,
		str(summary.get("current_level", SaveManager.DEFAULT_LEVEL_ID)),
		int(summary.get("unlocked_character_count", 0)),
		str(summary.get("updated_at", ""))
	]


## Returns the primary action text for the current mode and slot state.
func _select_button_text(exists: bool) -> String:
	if mode == Mode.START:
		return tr("SAVE_USED") if exists else tr("SAVE_NEW")
	return tr("SAVE_LOAD")


## Creates or loads the selected slot based on the current picker mode.
func _on_select_slot(slot_index: int) -> void:
	var success: bool = false
	if mode == Mode.START:
		success = SaveManager.create_new_slot(slot_index)
	else:
		success = SaveManager.load_slot(slot_index)
	if success:
		close()
		enter_game_requested.emit()
	else:
		_refresh()


## Opens the delete confirmation dialog for an existing slot.
func _request_delete_slot(slot_index: int) -> void:
	pending_delete_slot = slot_index
	delete_confirm_dialog.dialog_text = tr("SAVE_DELETE_CONFIRM") % pending_delete_slot
	delete_confirm_dialog.popup_centered()


## Deletes the confirmed slot and refreshes the list.
func _confirm_delete_slot() -> void:
	if pending_delete_slot == 0:
		return
	SaveManager.delete_slot(pending_delete_slot)
	pending_delete_slot = 0
	_refresh()


## Applies the existing paper-button style to the save panel.
func _apply_styles() -> void:
	panel.add_theme_stylebox_override("panel", _style(PAPER, 16, 4))
	for button: Button in select_buttons:
		button.add_theme_stylebox_override("normal", _style(Color(0.91, 0.74, 0.35, 1.0), 10, 2))
		button.add_theme_stylebox_override("hover", _style(Color(1.0, 0.86, 0.45), 10, 2))
		button.add_theme_color_override("font_color", INK)
	for button: Button in delete_buttons:
		button.add_theme_stylebox_override("normal", _style(Color(0.72, 0.44, 0.35, 1.0), 10, 2))
		button.add_theme_stylebox_override("hover", _style(Color(0.88, 0.54, 0.42, 1.0), 10, 2))
		button.add_theme_color_override("font_color", Color.WHITE)
	close_button.add_theme_stylebox_override("normal", _style(PAPER, 10, 2))
	close_button.add_theme_color_override("font_color", INK)


## Creates a reusable flat paper style.
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
