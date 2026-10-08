extends HBoxContainer
## Defines the BattleTopBar script.
class_name BattleTopBar

signal menu_requested
signal shop_requested

@onready var menu_button: Button = $MenuButton
@onready var ap_bar: ProgressBar = $ApBox/ApWrap/ApBar
@onready var ap_label: Label = $ApBox/ApWrap/ApLabel
@onready var status_label: Label = $StatusLabel
@onready var shop_button: Button = $ShopButton

@export var ap_normal_fill_style: StyleBoxFlat
@export var ap_ready_fill_style: StyleBoxFlat
@export var shop_normal_style: StyleBoxFlat
@export var shop_hover_style: StyleBoxFlat
@export var sell_normal_style: StyleBoxFlat
@export var sell_hover_style: StyleBoxFlat
@export var ap_normal_label_color: Color = Color.WHITE
@export var ap_ready_label_color: Color = Color(0.18, 0.12, 0.04)
@export var shop_font_size: int = 20
@export var sell_font_size: int = 17

var sell_mode: bool = false
var sell_drop_hovered: bool = false
var shop_unlocked: bool = false


func _ready() -> void:
	menu_button.pressed.connect(func() -> void: menu_requested.emit())
	shop_button.pressed.connect(_on_shop_button_pressed)


## Applies progression and turn-state locks as well as the existing battle status.
func refresh(ap: float, phase: BattleState.Phase, turn_count: int, current_wave: int, total_waves: int, general_cards_enabled: bool) -> void:
	shop_unlocked = general_cards_enabled
	shop_button.disabled = not shop_unlocked or phase != BattleState.Phase.PLAYER_TURN
	shop_button.tooltip_text = tr("UI_SHOP_HINT") if shop_unlocked else tr("GENERAL_CARDS_LOCKED_HINT")
	if not sell_mode:
		shop_button.text = tr("UI_SHOP") if shop_unlocked else tr("UI_SHOP_LOCKED")
	ap_bar.value = ap
	ap_label.text = "%.1f / 5.0" % ap
	if ap >= 5.0:
		ap_bar.add_theme_stylebox_override("fill", ap_ready_fill_style)
		ap_label.add_theme_color_override("font_color", ap_ready_label_color)
	else:
		ap_bar.add_theme_stylebox_override("fill", ap_normal_fill_style)
		ap_label.add_theme_color_override("font_color", ap_normal_label_color)

	status_label.text = "%s\n%s  %s" % [
		_phase_text(phase),
		tr("ROUND_FORMAT") % turn_count,
		tr("WAVE_FORMAT") % [current_wave, total_waves]
	]


func begin_sell_mode(sell_price: float) -> void:
	if not shop_unlocked:
		return
	sell_mode = true
	sell_drop_hovered = false
	shop_button.text = "%s\n%s" % [tr("UI_SELL"), _format_amount(sell_price)]
	_apply_shop_button_style(false)


func update_sell_drop_hover(mouse_global_position: Vector2) -> void:
	if not sell_mode:
		return
	var next_hovered: bool = is_sell_drop_target(mouse_global_position)
	if next_hovered == sell_drop_hovered:
		return
	sell_drop_hovered = next_hovered
	_apply_shop_button_style(sell_drop_hovered)


func end_sell_mode() -> void:
	if not sell_mode:
		return
	sell_mode = false
	sell_drop_hovered = false
	shop_button.text = tr("UI_SHOP") if shop_unlocked else tr("UI_SHOP_LOCKED")
	_apply_shop_button_style(false)


func is_sell_drop_target(mouse_global_position: Vector2) -> bool:
	if not sell_mode:
		return false
	var local_position: Vector2 = shop_button.get_global_transform_with_canvas().affine_inverse() * mouse_global_position
	return Rect2(Vector2.ZERO, shop_button.size).has_point(local_position)


func _on_shop_button_pressed() -> void:
	if shop_unlocked and not sell_mode:
		shop_requested.emit()


func _apply_shop_button_style(highlighted: bool) -> void:
	var normal_style: StyleBoxFlat = sell_normal_style if sell_mode else shop_normal_style
	var hover_style: StyleBoxFlat = sell_hover_style if sell_mode else shop_hover_style
	if highlighted:
		normal_style = hover_style
	shop_button.add_theme_stylebox_override("normal", normal_style)
	shop_button.add_theme_stylebox_override("hover", hover_style)
	shop_button.add_theme_font_size_override("font_size", sell_font_size if sell_mode else shop_font_size)


func _format_amount(amount: float) -> String:
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
		BattleState.Phase.ANSWER_RESULT:
			return tr("PHASE_ANSWER_RESULT")
		BattleState.Phase.ACTION_RESOLUTION:
			return tr("PHASE_ACTION_RESOLUTION")
		BattleState.Phase.ENEMY_TURN:
			return tr("PHASE_ENEMY")
		BattleState.Phase.VICTORY:
			return tr("PHASE_VICTORY")
		BattleState.Phase.DEFEAT:
			return tr("PHASE_DEFEAT")
		_:
			return tr("PHASE_READY")
