extends Control
## Owns the left-side drawer used to select one optional learning goal.
class_name LearningGoalDrawer

signal goal_source_selected(character_id: String)

const ENTRY_SCENE: PackedScene = preload("res://scenes/ui/LearningGoalEntry.tscn")

@export var drawer_width: float = 460.0

var available_characters: Array[CharacterData] = []
var selected_character_id: String = ""
var drawer_tween: Tween

@onready var outside_click_area: Button = $OutsideClickArea
@onready var drawer_panel: PanelContainer = $DrawerPanel
@onready var title_label: Label = $DrawerPanel/Content/TitleLabel
@onready var clear_button: Button = $DrawerPanel/Content/ClearButton
@onready var goal_list: VBoxContainer = $DrawerPanel/Content/GoalScroll/GoalList


## Connects local controls and initializes the drawer as closed.
func _ready() -> void:
	outside_click_area.pressed.connect(close.bind(true))
	clear_button.pressed.connect(_clear_selection)
	LanguageManager.language_changed.connect(_on_language_changed)
	close(false)


## Opens the drawer with all characters unlocked in the active save.
func open_with(characters: Array[CharacterData], selected_id: String) -> void:
	available_characters = characters
	selected_character_id = selected_id
	_refresh_text()
	_rebuild_entries()
	_set_open(true, true)


## Closes the drawer without changing the selected goal.
func close(animated: bool = true) -> void:
	_set_open(false, animated)


## Returns whether the drawer currently accepts interaction.
func is_open() -> bool:
	return visible and mouse_filter == Control.MOUSE_FILTER_STOP


## Refreshes translated drawer content after a locale change.
func _on_language_changed(_locale: String) -> void:
	if not visible:
		return
	_refresh_text()
	_rebuild_entries()


## Updates static translated labels.
func _refresh_text() -> void:
	title_label.text = tr("LEARNING_GOAL_DRAWER_TITLE")
	clear_button.text = tr("LEARNING_GOAL_CLEAR")


## Rebuilds goal entries from the unlocked character list.
func _rebuild_entries() -> void:
	for child: Node in goal_list.get_children():
		child.queue_free()
	for character: CharacterData in available_characters:
		var goal: LearningGoalData = LearningGoalDatabase.create_goal_for_character(character)
		if goal == null:
			continue
		var entry: LearningGoalEntry = ENTRY_SCENE.instantiate() as LearningGoalEntry
		goal_list.add_child(entry)
		entry.setup(character, goal, character.id == selected_character_id)
		entry.goal_source_selected.connect(_select_source)


## Selects one source, emits it, and closes the drawer.
func _select_source(character_id: String) -> void:
	selected_character_id = character_id
	goal_source_selected.emit(character_id)
	close(true)


## Clears the optional goal and closes the drawer.
func _clear_selection() -> void:
	selected_character_id = ""
	goal_source_selected.emit("")
	close(true)


## Animates the left drawer between its hidden and visible positions.
func _set_open(open: bool, animated: bool) -> void:
	if drawer_tween != null:
		drawer_tween.kill()
	visible = true
	mouse_filter = Control.MOUSE_FILTER_STOP if open else Control.MOUSE_FILTER_IGNORE
	var target_x: float = 0.0 if open else -drawer_width
	if not animated:
		drawer_panel.position.x = target_x
		visible = open
		return
	if open:
		drawer_panel.position.x = -drawer_width
	drawer_tween = create_tween()
	drawer_tween.set_ease(Tween.EASE_OUT)
	drawer_tween.set_trans(Tween.TRANS_CUBIC)
	drawer_tween.tween_property(drawer_panel, "position:x", target_x, 0.22)
	if not open:
		drawer_tween.finished.connect(func() -> void: visible = false)
