extends Control
## Shows permanent Old TOEFL card unlocks at David's map stall.
class_name VendorPanel

signal challenge_requested

const ITEM_SCENE: PackedScene = preload("res://scenes/ui/ShopCardItem.tscn")
@onready var balance_label: Label = $Panel/Box/Header/Balance
@onready var cards_grid: GridContainer = $Panel/Box/Scroll/Cards
@onready var message_label: Label = $Panel/Box/Message
@onready var close_button: Button = $Panel/Box/Footer/Close
@onready var challenge_button: Button = $Panel/Box/Footer/Challenge

var cards: Array[CardData] = []


## Connects local controls and refreshes permanent ownership when language changes.
func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	close_button.pressed.connect(hide)
	challenge_button.pressed.connect(_challenge)
	LanguageManager.language_changed.connect(_on_language_changed)
	hide()


## Opens the stall only after the feature unlocking clear.
func open_stall() -> void:
	if not SaveManager.are_general_cards_unlocked():
		return
	show()
	_refresh()
	close_button.grab_focus()


## Builds card previews and expands authored line breaks in the stall description.
func _refresh() -> void:
	balance_label.text = tr("VENDOR_OLD_BALANCE") % SaveManager.get_old_toefl()
	message_label.text = tr("VENDOR_UNLOCK_DESCRIPTION").replace("\\n", "\n")
	cards = CardDatabase.create_vendor_cards()
	for child: Node in cards_grid.get_children():
		cards_grid.remove_child(child)
		child.queue_free()
	for index in cards.size():
		var item: ShopCardItem = ITEM_SCENE.instantiate() as ShopCardItem
		cards_grid.add_child(item)
		item.setup_unlock_card(cards[index], index, SaveManager.get_old_toefl(), SaveManager.is_general_card_unlocked(cards[index].id))
		item.buy_requested.connect(_purchase)


## Delegates the one-time currency transaction and unlock to SaveManager.
func _purchase(index: int) -> void:
	if index < 0 or index >= cards.size():
		return
	var name_key: String = cards[index].display_name
	if SaveManager.purchase_general_unlock(cards[index].id):
		_refresh()
		message_label.text = tr("VENDOR_CARD_UNLOCKED") % tr(name_key)


## Preserves an explicit replay route after the Locker becomes a stall.
func _challenge() -> void:
	hide()
	challenge_requested.emit()


## Updates visible offers without reopening a closed stall.
func _on_language_changed(_locale: String) -> void:
	if visible:
		_refresh()
