extends PanelContainer
class_name DeveloperControls

signal add_festival_mask_requested
signal add_general_card_requested

@onready var add_festival_mask_button: Button = $Box/AddFestivalMaskButton
@onready var add_general_card_button: Button = $Box/AddGeneralCardButton


func _ready() -> void:
	add_festival_mask_button.pressed.connect(func() -> void: add_festival_mask_requested.emit())
	add_general_card_button.pressed.connect(func() -> void: add_general_card_requested.emit())
	SettingsManager.developer_mode_changed.connect(_on_developer_mode_changed)
	_on_developer_mode_changed(SettingsManager.developer_mode)


func _on_developer_mode_changed(enabled: bool) -> void:
	visible = enabled
