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
	quit()
