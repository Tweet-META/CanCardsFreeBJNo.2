extends VBoxContainer
class_name ShopCardItem

signal buy_requested(offer_index: int)

const INK: Color = Color(0.12, 0.10, 0.08)

@onready var card_preview: CardButton = $CardPreview
@onready var price_label: Label = $PriceLabel
@onready var buy_button: Button = $BuyButton

var offer_index: int = -1


func _ready() -> void:
	buy_button.pressed.connect(_on_buy_pressed)
	buy_button.add_theme_stylebox_override("normal", _style(Color(0.78, 0.88, 0.62), 10, 2))
	buy_button.add_theme_stylebox_override("hover", _style(Color(0.88, 0.96, 0.70), 10, 2))
	buy_button.add_theme_stylebox_override("disabled", _style(Color(0.55, 0.52, 0.46), 10, 1))
	buy_button.add_theme_color_override("font_color", INK)


func setup(card: CardData, index: int, current_ap: float, balance: float) -> void:
	offer_index = index
	card_preview.setup(card, index, current_ap, false)
	card_preview.set_interaction_locked(true)
	price_label.text = tr("UI_PRICE_FORMAT") % card.shop_price
	buy_button.disabled = balance + 0.001 < card.shop_price


func _on_buy_pressed() -> void:
	if offer_index >= 0:
		buy_requested.emit(offer_index)


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
