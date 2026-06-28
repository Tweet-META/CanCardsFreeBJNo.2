extends PanelContainer
## Defines the SettingsPanel script.
class_name SettingsPanel

@onready var close_button: Button = $Box/CloseButton


## Ready.
func _ready() -> void:
	_apply_export_safe_layout()
	close_button.pressed.connect(hide)
	hide()


## Apply export safe layout.
func _apply_export_safe_layout() -> void:
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


## Open.
func open() -> void:
	show()
