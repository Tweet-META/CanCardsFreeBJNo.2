extends PanelContainer
## Defines the ResultPanel script.
class_name ResultPanel

signal retry_requested
signal menu_requested
signal dismissed

@onready var title_label: Label = $Box/TitleLabel
@onready var message_label: Label = $Box/MessageLabel
@onready var retry_button: Button = $Box/ButtonRow/RetryButton
@onready var menu_button: Button = $Box/ButtonRow/MenuButton
@onready var close_button: Button = $Box/ButtonRow/CloseButton


## Ready.
func _ready() -> void:
	_apply_export_safe_layout()
	add_theme_stylebox_override("panel", _style(Color(0.88, 0.80, 0.66, 0.98), 10, 4))
	close_button.pressed.connect(_close_non_battle_result)
	retry_button.pressed.connect(_on_retry)
	menu_button.pressed.connect(func() -> void: menu_requested.emit())
	hide()


## Apply export safe layout.
func _apply_export_safe_layout() -> void:
	set_anchors_preset(Control.PRESET_CENTER)
	offset_left = -260.0
	offset_top = -130.0
	offset_right = 260.0
	offset_bottom = 130.0


## Show result.
func show_result(title: String, message: String, battle_over: bool, _victory: bool) -> void:
	title_label.text = title
	message_label.text = message
	retry_button.visible = battle_over
	menu_button.visible = battle_over
	close_button.visible = not battle_over
	show()


## On retry.
func _on_retry() -> void:
	hide()
	dismissed.emit()
	retry_requested.emit()


## Close non battle result.
func _close_non_battle_result() -> void:
	hide()
	dismissed.emit()


## Style.
func _style(color: Color, radius: int, border_width: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
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
	style.shadow_color = Color(0, 0, 0, 0.28)
	style.shadow_size = 8
	return style
