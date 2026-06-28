extends Control
## Controls the main menu, language picker, settings, and save-slot entry points.

@onready var start_button: Button = $CenterBox/StartButton
@onready var load_save_button: Button = $CenterBox/LoadSaveButton
@onready var language_option: OptionButton = $CenterBox/LanguageRow/LanguageOption
@onready var quit_button: Button = $CenterBox/QuitButton
@onready var settings_button: Button = $CenterBox/SettingsButton
@onready var settings_panel: SettingsPanel = $SettingsPanel
@onready var save_slot_panel: SaveSlotPanel = $SaveSlotPanel


## Connects menu buttons and initializes localized controls.
func _ready() -> void:
	start_button.pressed.connect(_on_start_pressed)
	load_save_button.pressed.connect(_on_load_save_pressed)
	language_option.item_selected.connect(_on_language_selected)
	quit_button.pressed.connect(func() -> void: get_tree().quit())
	settings_button.pressed.connect(settings_panel.open)
	save_slot_panel.enter_game_requested.connect(_enter_game)
	_refresh_language_options()
	LanguageManager.language_changed.connect(_on_language_changed)


## Opens the save picker in new-game mode.
func _on_start_pressed() -> void:
	save_slot_panel.open_for_start()


## Opens the save picker in load/delete mode.
func _on_load_save_pressed() -> void:
	save_slot_panel.open_for_load()


## Enters the map after a save slot has been created or loaded.
func _enter_game() -> void:
	get_tree().change_scene_to_file("res://scenes/MapScene.tscn")


## Switches the active localization.
func _on_language_selected(index: int) -> void:
	var locale: String = "zh_CN" if index == 0 else "en"
	LanguageManager.set_language(locale)


## Refreshes menu text after a language change.
func _on_language_changed(_locale: String) -> void:
	_refresh_language_options()


## Rebuilds the language option labels using the current locale.
func _refresh_language_options() -> void:
	language_option.clear()
	language_option.add_item(tr("LANGUAGE_ZH_CN"))
	language_option.add_item(tr("LANGUAGE_EN"))
	language_option.select(0 if LanguageManager.get_language() == "zh_CN" else 1)
