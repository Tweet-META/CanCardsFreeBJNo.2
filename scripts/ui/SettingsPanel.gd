extends PanelContainer
## 主菜单设置面板，目前用于切换并同步开发者模式。
class_name SettingsPanel

@onready var developer_mode_checkbox: CheckBox = $Box/DeveloperModeCheckBox
@onready var close_button: Button = $Box/CloseButton


func _ready() -> void:
	_apply_export_safe_layout()
	developer_mode_checkbox.toggled.connect(SettingsManager.set_developer_mode)
	close_button.pressed.connect(hide)
	SettingsManager.developer_mode_changed.connect(_on_developer_mode_changed)
	_on_developer_mode_changed(SettingsManager.developer_mode)
	hide()


func _apply_export_safe_layout() -> void:
	# 导出后仍以完整视口为参照居中，不依赖子场景实例的隐式布局继承。
	anchor_left = 0.5
	anchor_top = 0.5
	anchor_right = 0.5
	anchor_bottom = 0.5
	offset_left = -220.0
	offset_top = -135.0
	offset_right = 220.0
	offset_bottom = 135.0
	grow_horizontal = Control.GROW_DIRECTION_BOTH
	grow_vertical = Control.GROW_DIRECTION_BOTH


func open() -> void:
	_on_developer_mode_changed(SettingsManager.developer_mode)
	show()


func _on_developer_mode_changed(enabled: bool) -> void:
	developer_mode_checkbox.set_pressed_no_signal(enabled)
