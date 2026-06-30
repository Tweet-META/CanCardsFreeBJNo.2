extends PanelContainer
## Defines the QuestionPanel script.
class_name QuestionPanel

signal difficulty_selected(difficulty: String)
signal answer_submitted(answer_index: int)

@onready var difficulty_title: Label = $Box/DifficultyTitle
@onready var difficulty_buttons: Array[Button] = [
	$Box/DifficultyButton0,
	$Box/DifficultyButton1,
	$Box/DifficultyButton2
]
@onready var prompt_label: Label = $Box/PromptLabel
@onready var option_buttons: Array[Button] = [
	$Box/OptionButton0,
	$Box/OptionButton1,
	$Box/OptionButton2,
	$Box/OptionButton3
]


## Ready.
func _ready() -> void:
	_apply_export_safe_layout()
	add_theme_stylebox_override("panel", _style(Color(0.88, 0.80, 0.66, 0.98), 10, 4))
	for i in difficulty_buttons.size():
		difficulty_buttons[i].pressed.connect(_submit_difficulty.bind(i))
	for i in option_buttons.size():
		option_buttons[i].pressed.connect(_submit_answer.bind(i))
	hide()


## Apply export safe layout.
func _apply_export_safe_layout() -> void:
	set_anchors_preset(Control.PRESET_CENTER)
	offset_left = -310.0
	offset_top = -180.0
	offset_right = 310.0
	offset_bottom = 180.0


## Show difficulty selection.
func show_difficulty_selection() -> void:
	difficulty_title.text = tr("QUESTION_SELECT_DIFFICULTY")
	var difficulties: Array[String] = ["easy", "medium", "hard"]
	for i in difficulty_buttons.size():
		difficulty_buttons[i].text = _difficulty_label(difficulties[i])
	_set_difficulty_controls_visible(true)
	_set_question_controls_visible(false)
	show()


## Show question.
func show_question(question: QuestionData) -> void:
	_set_difficulty_controls_visible(false)
	_set_question_controls_visible(true)
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


## Submit difficulty.
func _submit_difficulty(index: int) -> void:
	var difficulties: Array[String] = ["easy", "medium", "hard"]
	if index < 0 or index >= difficulties.size():
		return
	difficulty_selected.emit(difficulties[index])


## Submit answer.
func _submit_answer(index: int) -> void:
	hide()
	answer_submitted.emit(index)


## Set difficulty controls visible.
func _set_difficulty_controls_visible(should_show: bool) -> void:
	difficulty_title.visible = should_show
	for button: Button in difficulty_buttons:
		button.visible = should_show


## Set question controls visible.
func _set_question_controls_visible(should_show: bool) -> void:
	prompt_label.visible = should_show
	for button: Button in option_buttons:
		button.visible = should_show


## Category label.
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


## Difficulty label.
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


## Style.
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
