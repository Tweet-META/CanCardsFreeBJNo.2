extends SceneTree
## 验证 questions.json 被真实加载，防止解析失败后静默使用内置题库。


func _init() -> void:
	var bank: QuestionBank = QuestionBank.new()
	var json_value: Variant = JSON.parse_string(FileAccess.get_file_as_string(QuestionBank.QUESTIONS_PATH))
	assert(json_value is Array)
	var json_questions: Array = json_value as Array

	assert(not json_questions.is_empty())
	assert(bank.questions.size() == json_questions.size())
	assert(bank.questions[0].id == str((json_questions[0] as Dictionary).get("id", "")))
	assert(bank.questions[0].prompt.begins_with("Q_"))
	assert(bank.questions[0].explanation.ends_with("_EXPLANATION"))

	var medium_pool: Array[QuestionData] = bank.get_questions_for_difficulty("medium")
	assert(not medium_pool.is_empty())
	var medium_categories: Dictionary = {}
	for question: QuestionData in medium_pool:
		assert(question.difficulty == "medium")
		medium_categories[question.category] = true
	assert(medium_categories.size() == 3)

	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 20260621
	var hard_question: QuestionData = bank.get_random_question_by_difficulty("hard", rng)
	assert(hard_question.difficulty == "hard")

	var source_question: QuestionData = bank.questions[0]
	var source_options: Array[String] = source_question.options.duplicate()
	var correct_option: String = source_question.options[source_question.correct_index]
	var shuffle_rng: RandomNumberGenerator = RandomNumberGenerator.new()
	shuffle_rng.seed = 42
	var shuffled_question: QuestionData = source_question.create_shuffled_copy(shuffle_rng)
	assert(shuffled_question != source_question)
	assert(shuffled_question.options.size() == source_question.options.size())
	assert(shuffled_question.options[shuffled_question.correct_index] == correct_option)
	assert(source_question.options == source_options)
	for option: String in source_options:
		assert(shuffled_question.options.has(option))
	quit()
