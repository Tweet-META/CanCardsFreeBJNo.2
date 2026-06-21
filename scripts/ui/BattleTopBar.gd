extends HBoxContainer
## 顶部 AP 条、回合状态、暂停入口和商店入口。
class_name BattleTopBar

signal menu_requested
signal shop_requested

const PAPER: Color = Color(0.86, 0.78, 0.64, 0.96)
const INK: Color = Color(0.12, 0.10, 0.08)

@onready var menu_button: Button = $MenuButton
@onready var ap_bar: ProgressBar = $ApBox/ApWrap/ApBar
@onready var ap_label: Label = $ApBox/ApWrap/ApLabel
@onready var status_label: Label = $StatusLabel
@onready var shop_button: Button = $ShopButton

var sell_mode: bool = false
var sell_drop_hovered: bool = false


func _ready() -> void:
	menu_button.pressed.connect(func() -> void: menu_requested.emit())
	shop_button.pressed.connect(_on_shop_button_pressed)
	_apply_styles()


func refresh(ap: float, phase: BattleState.Phase, turn_count: int, current_wave: int, total_waves: int) -> void:
	# AP 满时整条切换为金色，与技能卡解锁状态保持一致。
	ap_bar.value = ap
	ap_label.text = "%.1f / 5.0" % ap
	if ap >= 5.0:
		ap_bar.add_theme_stylebox_override("fill", _style(Color(0.96, 0.70, 0.22), 14, 1))
		ap_label.add_theme_color_override("font_color", Color(0.18, 0.12, 0.04))
	else:
		ap_bar.add_theme_stylebox_override("fill", _style(Color(0.24, 0.58, 0.90), 14, 1))
		ap_label.add_theme_color_override("font_color", Color.WHITE)

	status_label.text = "%s\n%s  %s" % [
		_phase_text(phase),
		tr("ROUND_FORMAT") % turn_count,
		tr("WAVE_FORMAT") % [current_wave, total_waves]
	]


func begin_sell_mode(sell_price: float) -> void:
	# 拖动通用牌时复用商店按钮作为出售落点，第二行只显示本次售价数字。
	sell_mode = true
	sell_drop_hovered = false
	shop_button.text = "%s\n%s" % [tr("UI_SELL"), _format_amount(sell_price)]
	_apply_shop_button_style(false)


func update_sell_drop_hover(global_position: Vector2) -> void:
	if not sell_mode:
		return
	var next_hovered: bool = is_sell_drop_target(global_position)
	if next_hovered == sell_drop_hovered:
		return
	sell_drop_hovered = next_hovered
	_apply_shop_button_style(sell_drop_hovered)


func end_sell_mode() -> void:
	if not sell_mode:
		return
	sell_mode = false
	sell_drop_hovered = false
	shop_button.text = tr("UI_SHOP")
	_apply_shop_button_style(false)


func is_sell_drop_target(global_position: Vector2) -> bool:
	if not sell_mode:
		return false
	var local_position: Vector2 = shop_button.get_global_transform_with_canvas().affine_inverse() * global_position
	return Rect2(Vector2.ZERO, shop_button.size).has_point(local_position)


func _apply_styles() -> void:
	menu_button.add_theme_stylebox_override("normal", _style(PAPER, 28, 4))
	menu_button.add_theme_stylebox_override("hover", _style(Color(0.94, 0.87, 0.72), 28, 4))
	menu_button.add_theme_font_size_override("font_size", 24)

	ap_bar.add_theme_stylebox_override("background", _style(Color(0.40, 0.36, 0.29, 0.98), 16, 4))
	ap_bar.add_theme_stylebox_override("fill", _style(Color(0.24, 0.58, 0.90), 14, 1))
	ap_label.add_theme_color_override("font_color", Color.WHITE)
	ap_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.42))
	ap_label.add_theme_constant_override("shadow_offset_x", 1)
	ap_label.add_theme_constant_override("shadow_offset_y", 2)

	status_label.add_theme_color_override("font_color", INK)
	var status_style: StyleBoxFlat = _style(PAPER, 16, 3)
	status_style.content_margin_left = 14.0
	status_label.add_theme_stylebox_override("normal", status_style)

	shop_button.add_theme_color_override("font_color", INK)
	_apply_shop_button_style(false)


func _on_shop_button_pressed() -> void:
	# 出售拖拽期间按钮只是落点，不能同时打开商店面板。
	if not sell_mode:
		shop_requested.emit()


func _apply_shop_button_style(highlighted: bool) -> void:
	var normal_color: Color = Color(0.72, 0.90, 0.62) if sell_mode else Color(0.91, 0.78, 0.54)
	var hover_color: Color = Color(0.84, 1.0, 0.70) if sell_mode else Color(1.0, 0.86, 0.60)
	if highlighted:
		normal_color = hover_color
	shop_button.add_theme_stylebox_override("normal", _style(normal_color, 16, 3))
	shop_button.add_theme_stylebox_override("hover", _style(hover_color, 16, 3))
	shop_button.add_theme_font_size_override("font_size", 17 if sell_mode else 20)


func _format_amount(amount: float) -> String:
	# 最多显示两位小数，并去掉无意义的末尾零。
	var text: String = "%.2f" % amount
	while text.contains(".") and text.ends_with("0"):
		text = text.left(text.length() - 1)
	if text.ends_with("."):
		text = text.left(text.length() - 1)
	return text


func _phase_text(phase: BattleState.Phase) -> String:
	match phase:
		BattleState.Phase.PLAYER_TURN:
			return tr("PHASE_PLAYER")
		BattleState.Phase.DIFFICULTY_SELECTION:
			return tr("PHASE_DIFFICULTY")
		BattleState.Phase.QUESTION:
			return tr("PHASE_QUESTION")
		BattleState.Phase.ENEMY_TURN:
			return tr("PHASE_ENEMY")
		BattleState.Phase.VICTORY:
			return tr("PHASE_VICTORY")
		BattleState.Phase.DEFEAT:
			return tr("PHASE_DEFEAT")
		_:
			return tr("PHASE_READY")


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
