extends PanelContainer
class_name CancelDropArea

const INK: Color = Color(0.12, 0.10, 0.08)

@onready var label: Label = $Label


func _ready() -> void:
	visible = false
	z_index = 250
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_hovered(false)


func show_area() -> void:
	visible = true
	set_hovered(false)


func hide_area() -> void:
	visible = false
	set_hovered(false)


func set_hovered(hovered: bool) -> void:
	add_theme_stylebox_override("panel", _cancel_drop_style(hovered))
	label.add_theme_color_override("font_color", Color.WHITE if hovered else INK)


func _cancel_drop_style(hovered: bool) -> StyleBoxFlat:
	var color: Color = Color(0.88, 0.80, 0.68, 0.90)
	var border_color: Color = Color(0.13, 0.10, 0.08)
	var shadow_color: Color = Color(0, 0, 0, 0.20)
	if hovered:
		color = Color(0.88, 0.30, 0.26, 0.96)
		border_color = Color(0.42, 0.08, 0.06)
		shadow_color = Color(0.72, 0.12, 0.08, 0.35)
	var style := _style(color, 18, 3)
	style.border_color = border_color
	style.shadow_color = shadow_color
	style.shadow_size = 8 if hovered else 5
	return style


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
	style.shadow_color = Color(0, 0, 0, 0.20)
	style.shadow_size = 5
	return style
