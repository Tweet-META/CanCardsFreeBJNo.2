extends PanelContainer
## 商店弹窗，展示随机通用卡并管理刷新与购买入口。
class_name ShopPanel

signal refresh_requested
signal buy_requested(offer_index: int)

const INK: Color = Color(0.12, 0.10, 0.08)
const SHOP_CARD_ITEM_SCENE: PackedScene = preload("res://scenes/ui/ShopCardItem.tscn")

@onready var balance_label: Label = $Box/Header/BalanceLabel
@onready var close_button: Button = $Box/Header/CloseButton
@onready var cards_row: HBoxContainer = $Box/CardsRow
@onready var refresh_button: Button = $Box/Footer/RefreshButton


func _ready() -> void:
	add_theme_stylebox_override("panel", _style(Color(0.88, 0.80, 0.66, 0.98), 10, 3))
	close_button.add_theme_stylebox_override("normal", _style(Color(0.94, 0.87, 0.72), 10, 2))
	close_button.add_theme_stylebox_override("hover", _style(Color(1.0, 0.78, 0.68), 10, 2))
	close_button.add_theme_color_override("font_color", INK)
	refresh_button.add_theme_stylebox_override("normal", _style(Color(0.70, 0.86, 0.96), 10, 2))
	refresh_button.add_theme_stylebox_override("hover", _style(Color(0.82, 0.94, 1.0), 10, 2))
	refresh_button.add_theme_stylebox_override("disabled", _style(Color(0.50, 0.50, 0.48), 10, 1))
	refresh_button.add_theme_color_override("font_color", INK)
	refresh_button.add_theme_color_override("font_disabled_color", Color(0.24, 0.23, 0.21))
	close_button.pressed.connect(close)
	refresh_button.pressed.connect(func() -> void: refresh_requested.emit())
	hide()


func toggle() -> void:
	visible = not visible


func close() -> void:
	hide()


func refresh(balance: float, offers: Array[CardData], current_ap: float) -> void:
	# 每次商店状态变化都重建报价项，避免旧价格和禁用状态残留。
	balance_label.text = tr("UI_BALANCE_FORMAT") % balance
	refresh_button.disabled = balance + 0.001 < 0.5
	if not visible:
		return

	_clear_cards()
	for i in offers.size():
		var item: ShopCardItem = SHOP_CARD_ITEM_SCENE.instantiate() as ShopCardItem
		cards_row.add_child(item)
		item.buy_requested.connect(_on_item_buy_requested)
		item.setup(offers[i], i, current_ap, balance)


func _on_item_buy_requested(offer_index: int) -> void:
	buy_requested.emit(offer_index)


func _clear_cards() -> void:
	for child: Node in cards_row.get_children():
		cards_row.remove_child(child)
		child.queue_free()


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
