extends PanelContainer
## Defines the DeveloperControls script.
class_name DeveloperControls

signal add_culture_mask_requested
signal add_general_card_requested
signal add_six_seven_requested
signal clear_enemies_requested
signal defeat_players_requested
signal skip_turn_requested

@onready var skip_turn_button: Button = $Scroll/Box/SkipTurnButton
@onready var add_culture_mask_button: Button = $Scroll/Box/AddCultureMaskButton
@onready var add_general_card_button: Button = $Scroll/Box/AddGeneralCardButton
@onready var add_six_seven_button: Button = $Scroll/Box/AddSixSevenButton
@onready var clear_enemies_button: Button = $Scroll/Box/ClearEnemiesButton
@onready var defeat_players_button: Button = $Scroll/Box/DefeatPlayersButton


func _ready() -> void:
	_apply_export_safe_layout()
	skip_turn_button.pressed.connect(func() -> void: skip_turn_requested.emit())
	add_culture_mask_button.pressed.connect(func() -> void: add_culture_mask_requested.emit())
	add_general_card_button.pressed.connect(func() -> void: add_general_card_requested.emit())
	add_six_seven_button.pressed.connect(func() -> void: add_six_seven_requested.emit())
	clear_enemies_button.pressed.connect(func() -> void: clear_enemies_requested.emit())
	defeat_players_button.pressed.connect(func() -> void: defeat_players_requested.emit())
	SettingsManager.developer_mode_changed.connect(_on_developer_mode_changed)
	_on_developer_mode_changed(SettingsManager.developer_mode)


func _apply_export_safe_layout() -> void:
	custom_minimum_size = Vector2(260, 288)
	anchor_left = 0.5
	anchor_top = 0.0
	anchor_right = 0.5
	anchor_bottom = 0.0
	offset_left = -300.0
	offset_top = 98.0
	offset_right = -40.0
	offset_bottom = 386.0


func _on_developer_mode_changed(enabled: bool) -> void:
	visible = enabled
