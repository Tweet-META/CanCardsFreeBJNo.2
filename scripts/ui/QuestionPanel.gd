extends PanelContainer
## 答题面板，显示题目并提交选项索引，不自行判断正确答案。
class_name QuestionPanel

signal answer_submitted(answer_index: int)

@onready var prompt_label: Label = $Box/PromptLabel
@onready var option_buttons: Array[Button] = [
	$Box/OptionButton0,
	$Box/OptionButton1,
	$Box/OptionButton2,
	$Box/OptionButton3
]


func _ready() -> void:
	add_theme_stylebox_override("panel", _style(Color(0.88, 0.80, 0.66, 0.98), 10, 4))
	for i in option_buttons.size():
		option_buttons[i].pressed.connect(_submit_answer.bind(i))
	hide()


func show_question(question: QuestionData) -> void:
	# 题目内容使用翻译键解析，本面板只负责显示与提交。
	prompt_label.text = tr("QUESTION_HEADER_FORMAT").replace("\\n", "\n") % [
		_category_label(question.category),
		_difficulty_label(question.difficulty),
		tr(question.prompt)
	]
	for i in option_buttons.size():
		var button: Button = option_buttons[i]
		button.text = tr(question.options[i]) if i < question.options.size() else "-"
		button.disabled = i >= question.options.size()
	show()


func _submit_answer(index: int) -> void:
	hide()
	answer_submitted.emit(index)


func _category_label(category: String) -> String:
	match category:
		"拼音":
			return tr("ATTRIBUTE_PINYIN")
		"词汇":
			return tr("ATTRIBUTE_VOCABULARY")
		"文化":
			return tr("ATTRIBUTE_CULTURE")
		_:
			return category


func _difficulty_label(difficulty: String) -> String:
	match difficulty:
		"easy":
			return tr("DIFFICULTY_EASY")
		"medium":
			return tr("DIFFICULTY_MEDIUM")
		"hard":
			return tr("DIFFICULTY_HARD")
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
