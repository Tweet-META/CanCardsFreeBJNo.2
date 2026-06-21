extends Control
## 单个地图关卡节点，显示解锁状态并向地图场景发送关卡选择。
class_name StageNode

signal stage_selected(stage: StageData)

const PAPER: Color = Color(0.91, 0.74, 0.35, 1.0)
const INK: Color = Color(0.18, 0.11, 0.04)

@onready var stage_button: Button = $StageButton
@onready var stage_label: Label = $StageLabel

var stage_data: StageData


func _ready() -> void:
	stage_button.pressed.connect(_on_pressed)
	_apply_styles()


func setup(stage: StageData) -> void:
	stage_data = stage
	stage_button.disabled = not stage.unlocked
	stage_button.text = stage.marker_text
	stage_label.text = tr(stage.display_name)
	stage_button.tooltip_text = tr(stage.description)
	modulate = Color.WHITE if stage.unlocked else Color(0.55, 0.55, 0.55, 0.85)


func refresh_language() -> void:
	if stage_data == null:
		return
	stage_label.text = tr(stage_data.display_name)
	stage_button.tooltip_text = tr(stage_data.description)


func _on_pressed() -> void:
	if stage_data != null and stage_data.unlocked:
		stage_selected.emit(stage_data)


func _apply_styles() -> void:
	stage_button.add_theme_stylebox_override("normal", _style(PAPER, 29, 4))
	stage_button.add_theme_stylebox_override("hover", _style(Color(1.0, 0.86, 0.45), 29, 4))
	stage_button.add_theme_stylebox_override("pressed", _style(Color(0.80, 0.60, 0.22), 29, 4))
	stage_button.add_theme_color_override("font_color", INK)


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
	style.border_color = Color(0.20, 0.13, 0.06)
	style.shadow_color = Color(0, 0, 0, 0.32)
	style.shadow_size = 8
	return style
