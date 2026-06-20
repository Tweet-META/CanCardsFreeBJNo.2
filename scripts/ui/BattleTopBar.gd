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


func _ready() -> void:
	menu_button.pressed.connect(func() -> void: menu_requested.emit())
	shop_button.pressed.connect(func() -> void: shop_requested.emit())
	_apply_styles()


func refresh(ap: float, phase: BattleState.Phase, turn_count: int) -> void:
	# AP 满时整条切换为金色，与技能卡解锁状态保持一致。
	ap_bar.value = ap
	ap_label.text = "%.1f / 5.0" % ap
	if ap >= 5.0:
		ap_bar.add_theme_stylebox_override("fill", _style(Color(0.96, 0.70, 0.22), 14, 1))
		ap_label.add_theme_color_override("font_color", Color(0.18, 0.12, 0.04))
	else:
		ap_bar.add_theme_stylebox_override("fill", _style(Color(0.24, 0.58, 0.90), 14, 1))
		ap_label.add_theme_color_override("font_color", Color.WHITE)

	status_label.text = "%s\n%s" % [_phase_text(phase), tr("ROUND_FORMAT") % turn_count]


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

	shop_button.add_theme_stylebox_override("normal", _style(Color(0.91, 0.78, 0.54), 16, 3))
	shop_button.add_theme_stylebox_override("hover", _style(Color(1.0, 0.86, 0.60), 16, 3))
	shop_button.add_theme_color_override("font_color", INK)
	shop_button.add_theme_font_size_override("font_size", 20)


func _phase_text(phase: BattleState.Phase) -> String:
	match phase:
		BattleState.Phase.PLAYER_TURN:
			return tr("PHASE_PLAYER")
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
