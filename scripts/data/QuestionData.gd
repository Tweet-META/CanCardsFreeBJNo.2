extends Resource
class_name QuestionData

@export var id: String = ""
@export var category: String = ""
@export var difficulty: String = "easy"
@export_multiline var prompt: String = ""
@export var options: Array[String] = []
@export_range(0, 3, 1) var correct_index: int = 0
@export_multiline var explanation: String = ""


func is_answer_correct(index: int) -> bool:
	return index == correct_index


func get_correct_answer_text() -> String:
	if correct_index < 0 or correct_index >= options.size():
		return ""
	return tr(options[correct_index])
