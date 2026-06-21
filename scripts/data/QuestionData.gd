extends Resource
## 一道题目的内容、选项和正确答案索引。
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


func create_shuffled_copy(rng: RandomNumberGenerator) -> QuestionData:
	# 通过原索引洗牌，确保即使两个选项文本相同也能准确追踪正确答案。
	var shuffled_question: QuestionData = QuestionData.new()
	shuffled_question.id = id
	shuffled_question.category = category
	shuffled_question.difficulty = difficulty
	shuffled_question.prompt = prompt
	shuffled_question.explanation = explanation

	var source_indices: Array[int] = []
	for index in options.size():
		source_indices.append(index)
	for index in range(source_indices.size() - 1, 0, -1):
		var swap_index: int = rng.randi_range(0, index)
		var previous_index: int = source_indices[index]
		source_indices[index] = source_indices[swap_index]
		source_indices[swap_index] = previous_index

	var shuffled_options: Array[String] = []
	for new_index in source_indices.size():
		var source_index: int = source_indices[new_index]
		shuffled_options.append(options[source_index])
		if source_index == correct_index:
			shuffled_question.correct_index = new_index
	shuffled_question.options = shuffled_options
	return shuffled_question
