extends PanelContainer
## Defines the DeveloperControls script.
class_name DeveloperControls

signal add_culture_mask_requested
signal add_general_card_requested
signal add_six_seven_requested
signal clear_enemies_requested
signal defeat_players_requested

@onready var add_culture_mask_button: Button = $Box/AddCultureMaskButton
@onready var add_general_card_button: Button = $Box/AddGeneralCardButton
@onready var add_six_seven_button: Button = $Box/AddSixSevenButton
@onready var clear_enemies_button: Button = $Box/ClearEnemiesButton
@onready var defeat_players_button: Button = $Box/DefeatPlayersButton


func _ready() -> void:
	_apply_export_safe_layout()
	add_culture_mask_button.pressed.connect(func() -> void: add_culture_mask_requested.emit())
	add_general_card_button.pressed.connect(func() -> void: add_general_card_requested.emit())
	add_six_seven_button.pressed.connect(func() -> void: add_six_seven_requested.emit())
	clear_enemies_button.pressed.connect(func() -> void: clear_enemies_requested.emit())
	defeat_players_button.pressed.connect(func() -> void: defeat_players_requested.emit())
	SettingsManager.developer_mode_changed.connect(_on_developer_mode_changed)
	_on_developer_mode_changed(SettingsManager.developer_mode)


func _apply_export_safe_layout() -> void:
	anchor_left = 0.5
	anchor_top = 0.0
	anchor_right = 0.5
	anchor_bottom = 0.0
	offset_left = -275.0
	offset_top = 98.0
	offset_right = -70.0
	offset_bottom = 386.0


func _on_developer_mode_changed(enabled: bool) -> void:
	visible = enabled
