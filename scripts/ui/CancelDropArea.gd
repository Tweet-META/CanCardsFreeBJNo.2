extends PanelContainer
## Defines the CancelDropArea script.
class_name CancelDropArea

@onready var label: Label = $Label

@export var normal_panel_style: StyleBoxFlat
@export var hovered_panel_style: StyleBoxFlat
@export var normal_label_color: Color = Color(0.12, 0.10, 0.08)
@export var hovered_label_color: Color = Color.WHITE


## Initializes the hidden cancel target and its non-interactive state.
func _ready() -> void:
	visible = false
	z_index = 250
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_hovered(false)


## Show area.
func show_area() -> void:
	visible = true
	set_hovered(false)


## Hide area.
func hide_area() -> void:
	visible = false
	set_hovered(false)


## Switches the editor-owned visual resources for the current hover state.
func set_hovered(hovered: bool) -> void:
	add_theme_stylebox_override("panel", hovered_panel_style if hovered else normal_panel_style)
	label.add_theme_color_override("font_color", hovered_label_color if hovered else normal_label_color)
