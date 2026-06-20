extends PanelContainer
class_name SettingsPanel

@onready var developer_mode_checkbox: CheckBox = $Box/DeveloperModeCheckBox
@onready var close_button: Button = $Box/CloseButton


func _ready() -> void:
	developer_mode_checkbox.toggled.connect(SettingsManager.set_developer_mode)
	close_button.pressed.connect(hide)
	SettingsManager.developer_mode_changed.connect(_on_developer_mode_changed)
	_on_developer_mode_changed(SettingsManager.developer_mode)
	hide()


func open() -> void:
	_on_developer_mode_changed(SettingsManager.developer_mode)
	show()


func _on_developer_mode_changed(enabled: bool) -> void:
	developer_mode_checkbox.set_pressed_no_signal(enabled)
