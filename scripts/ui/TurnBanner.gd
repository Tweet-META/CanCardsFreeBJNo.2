extends PanelContainer
## Displays a brief localized turn announcement above the battlefield.
class_name TurnBanner

@export_range(0.1, 5.0, 0.05) var display_seconds: float = 1.0

@onready var title_label: Label = $Title


## Shows the announcement for an editor-adjustable duration.
func play_announcement() -> void:
	title_label.text = tr("UI_ENEMY_TURN_START")
	show()
	await get_tree().create_timer(display_seconds).timeout
	hide()
