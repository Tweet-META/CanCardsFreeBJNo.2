extends Control
## 单个地图关卡节点，显示解锁状态并向地图场景发送关卡选择。
class_name LevelNode

signal level_selected(level: LevelData)

const PAPER: Color = Color(0.91, 0.74, 0.35, 1.0)
const INK: Color = Color(0.18, 0.11, 0.04)

@onready var level_button: Button = $LevelButton
@onready var level_label: Label = $LevelLabel

var level_data: LevelData


## 初始化关卡按钮点击信号和纸张风格。
func _ready() -> void:
	level_button.pressed.connect(_on_pressed)
	_apply_styles()


## 绑定关卡数据并刷新按钮数字、标题和解锁状态。
func setup(level: LevelData) -> void:
	level_data = level
	level_button.disabled = not level.unlocked
	level_button.text = level.marker_text
	level_label.text = tr(level.display_name)
	modulate = Color.WHITE if level.unlocked else Color(0.55, 0.55, 0.55, 0.85)


## 语言切换时刷新关卡标题。
func refresh_language() -> void:
	if level_data == null:
		return
	level_label.text = tr(level_data.display_name)


## 点击已解锁关卡时通知地图场景进入关卡。
func _on_pressed() -> void:
	if level_data != null and level_data.unlocked:
		level_selected.emit(level_data)


## 应用地图关卡按钮的统一样式。
func _apply_styles() -> void:
	level_button.add_theme_stylebox_override("normal", _style(PAPER, 29, 4))
	level_button.add_theme_stylebox_override("hover", _style(Color(1.0, 0.86, 0.45), 29, 4))
	level_button.add_theme_stylebox_override("pressed", _style(Color(0.80, 0.60, 0.22), 29, 4))
	level_button.add_theme_color_override("font_color", INK)


## 生成关卡按钮纸张样式。
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
