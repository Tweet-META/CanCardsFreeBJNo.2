extends PanelContainer
class_name ResultPanel

signal retry_requested
signal menu_requested

var title_label: Label
var message_label: Label
var retry_button: Button
var menu_button: Button
var close_button: Button


func _ready() -> void:
	_build_ui()
	hide()


func show_result(title: String, message: String, battle_over: bool, victory: bool) -> void:
	title_label.text = title
	message_label.text = message
	retry_button.visible = battle_over
	menu_button.visible = battle_over
	close_button.visible = not battle_over
	show()


func _build_ui() -> void:
	set_anchors_preset(Control.PRESET_CENTER)
	custom_minimum_size = Vector2(520, 260)
	offset_left = -260
	offset_top = -130
	offset_right = 260
	offset_bottom = 130
	add_theme_stylebox_override("panel", _style(Color(0.88, 0.80, 0.66, 0.98), 10, 4))

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	add_child(box)

	title_label = Label.new()
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_font_size_override("font_size", 30)
	box.add_child(title_label)

	message_label = Label.new()
	message_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	message_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(message_label)

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 12)
	box.add_child(row)

	close_button = Button.new()
	close_button.text = "继续"
	close_button.pressed.connect(func() -> void: hide())
	row.add_child(close_button)

	retry_button = Button.new()
	retry_button.text = "重新挑战"
	retry_button.pressed.connect(_on_retry)
	row.add_child(retry_button)

	menu_button = Button.new()
	menu_button.text = "回主菜单"
	menu_button.pressed.connect(func() -> void: menu_requested.emit())
	row.add_child(menu_button)


func _on_retry() -> void:
	hide()
	retry_requested.emit()


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
	style.shadow_color = Color(0, 0, 0, 0.28)
	style.shadow_size = 8
	return style
