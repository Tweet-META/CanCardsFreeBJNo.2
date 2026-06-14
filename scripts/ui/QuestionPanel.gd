extends PanelContainer
class_name QuestionPanel

signal answer_submitted(answer_index: int)

var prompt_label: Label
var option_buttons: Array[Button] = []


func _ready() -> void:
	_build_ui()
	hide()


func show_question(question: QuestionData) -> void:
	prompt_label.text = "[%s / %s]\n%s" % [_category_label(question.category), _difficulty_label(question.difficulty), question.prompt]
	for i in option_buttons.size():
		var button := option_buttons[i]
		button.text = question.options[i] if i < question.options.size() else "-"
		button.disabled = i >= question.options.size()
	show()


func _build_ui() -> void:
	set_anchors_preset(Control.PRESET_CENTER)
	custom_minimum_size = Vector2(620, 360)
	offset_left = -310
	offset_top = -180
	offset_right = 310
	offset_bottom = 180
	add_theme_stylebox_override("panel", _style(Color(0.88, 0.80, 0.66, 0.98), 10, 4))

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	add_child(box)

	prompt_label = Label.new()
	prompt_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	prompt_label.add_theme_font_size_override("font_size", 22)
	box.add_child(prompt_label)

	for i in 4:
		var button := Button.new()
		button.custom_minimum_size = Vector2(560, 48)
		button.pressed.connect(_submit_answer.bind(i))
		option_buttons.append(button)
		box.add_child(button)


func _submit_answer(index: int) -> void:
	hide()
	answer_submitted.emit(index)


func _category_label(category: String) -> String:
	return category


func _difficulty_label(difficulty: String) -> String:
	match difficulty:
		"easy":
			return "简单"
		"medium":
			return "中等"
		"hard":
			return "困难"
		_:
			return difficulty


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
