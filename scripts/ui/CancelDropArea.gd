extends PanelContainer
## 拖牌期间显示的取消投放区，并负责自身悬停视觉。
class_name CancelDropArea

const INK: Color = Color(0.12, 0.10, 0.08)

@onready var label: Label = $Label


## 初始化取消区的导出稳定布局、层级和默认隐藏状态。
func _ready() -> void:
	_apply_export_safe_layout()
	visible = false
	z_index = 250
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_hovered(false)


## 显示取消区并重置悬停视觉。
func show_area() -> void:
	_apply_export_safe_layout()
	visible = true
	set_hovered(false)


## 隐藏取消区并重置悬停视觉。
func hide_area() -> void:
	visible = false
	set_hovered(false)


## 根据鼠标是否位于取消区上方切换视觉状态。
func set_hovered(hovered: bool) -> void:
	add_theme_stylebox_override("panel", _cancel_drop_style(hovered))
	label.add_theme_color_override("font_color", Color.WHITE if hovered else INK)


## 在运行时重申锚点和偏移，避免导出构建丢失实例布局覆盖。
func _apply_export_safe_layout() -> void:
	set_anchors_preset(Control.PRESET_CENTER_BOTTOM, false)
	offset_left = -71.0
	offset_top = -92.0
	offset_right = 71.0
	offset_bottom = -40.0
	grow_horizontal = Control.GROW_DIRECTION_BOTH
	grow_vertical = Control.GROW_DIRECTION_BEGIN


## 创建取消区普通和悬停状态的样式。
func _cancel_drop_style(hovered: bool) -> StyleBoxFlat:
	var color: Color = Color(0.88, 0.80, 0.68, 0.90)
	var border_color: Color = Color(0.13, 0.10, 0.08)
	var shadow_color: Color = Color(0, 0, 0, 0.20)
	if hovered:
		color = Color(0.88, 0.30, 0.26, 0.96)
		border_color = Color(0.42, 0.08, 0.06)
		shadow_color = Color(0.72, 0.12, 0.08, 0.35)
	var style: StyleBoxFlat = _style(color, 18, 3)
	style.border_color = border_color
	style.shadow_color = shadow_color
	style.shadow_size = 8 if hovered else 5
	return style


## 生成圆角纸张样式盒。
func _style(color: Color, radius: int, border_width: int) -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
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
