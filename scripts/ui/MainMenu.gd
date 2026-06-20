extends Control

@onready var start_button: Button = $CenterBox/StartButton
@onready var language_option: OptionButton = $CenterBox/LanguageRow/LanguageOption
@onready var quit_button: Button = $CenterBox/QuitButton
@onready var settings_button: Button = $CenterBox/SettingsButton
@onready var settings_panel: SettingsPanel = $SettingsPanel


func _ready() -> void:
	start_button.pressed.connect(_on_start_pressed)
	language_option.item_selected.connect(_on_language_selected)
	quit_button.pressed.connect(func() -> void: get_tree().quit())
	settings_button.pressed.connect(settings_panel.open)
	_refresh_language_options()
	LanguageManager.language_changed.connect(_on_language_changed)


func _on_start_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/BattleScene.tscn")


func _on_language_selected(index: int) -> void:
	var locale: String = "zh_CN" if index == 0 else "en"
	LanguageManager.set_language(locale)


func _on_language_changed(_locale: String) -> void:
	_refresh_language_options()


func _refresh_language_options() -> void:
	language_option.clear()
	language_option.add_item(tr("LANGUAGE_ZH_CN"))
	language_option.add_item(tr("LANGUAGE_EN"))
	language_option.select(0 if LanguageManager.get_language() == "zh_CN" else 1)
