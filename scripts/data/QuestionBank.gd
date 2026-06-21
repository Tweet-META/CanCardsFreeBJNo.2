extends RefCounted
## 负责加载 questions.json，并按属性与难度随机提供题目。
class_name QuestionBank

const QUESTIONS_PATH: String = "res://data/questions.json"

var questions: Array[QuestionData] = []


func _init() -> void:
	if not load_from_json(QUESTIONS_PATH):
		_setup_default_questions()


func load_from_json(path: String) -> bool:
	# JSON 加载失败时返回 false，由构造函数回退到内置最小题库。
	if not FileAccess.file_exists(path):
		push_warning("Question JSON not found: %s" % path)
		return false

	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_warning("Failed to open question JSON: %s" % path)
		return false

	var json_text: String = file.get_as_text()
	var parsed: Variant = JSON.parse_string(json_text)
	if not parsed is Array:
		push_warning("Question JSON root must be an array: %s" % path)
		return false

	var parsed_items: Array = parsed
	var loaded_questions: Array[QuestionData] = []
	for item: Variant in parsed_items:
		if item is Dictionary:
			var question: QuestionData = _question_from_dictionary(item)
			if question != null:
				loaded_questions.append(question)

	if loaded_questions.is_empty():
		push_warning("Question JSON did not contain valid questions: %s" % path)
		return false

	questions = loaded_questions
	return true


func get_random_question(category: String, difficulty: String, rng: RandomNumberGenerator) -> QuestionData:
	# 优先精确匹配；该难度无题时退回同属性题目，保证战斗可继续。
	var candidates: Array[QuestionData] = []
	for question: QuestionData in questions:
		if question.category == category and question.difficulty == difficulty:
			candidates.append(question)

	if candidates.is_empty():
		for question: QuestionData in questions:
			if question.category == category:
				candidates.append(question)

	if candidates.is_empty():
		return questions[0].create_shuffled_copy(rng)

	return candidates[rng.randi_range(0, candidates.size() - 1)].create_shuffled_copy(rng)


func get_random_question_by_difficulty(difficulty: String, rng: RandomNumberGenerator) -> QuestionData:
	# 战斗抽题只按难度池筛选，题目属性不受出牌角色或卡牌属性限制。
	var candidates: Array[QuestionData] = get_questions_for_difficulty(difficulty)
	if candidates.is_empty():
		return questions[0].create_shuffled_copy(rng)
	return candidates[rng.randi_range(0, candidates.size() - 1)].create_shuffled_copy(rng)


func get_questions_for_difficulty(difficulty: String) -> Array[QuestionData]:
	var candidates: Array[QuestionData] = []
	for question: QuestionData in questions:
		if question.difficulty == difficulty:
			candidates.append(question)
	return candidates


func _setup_default_questions() -> void:
	# 只用于 questions.json 缺失或损坏时维持 MVP 可玩。
	questions = [
		_make_question("py_easy_1", "拼音", "easy", "“你好”的拼音是哪一个？", ["ni hao", "wo ai", "xie xie", "zai jian"], 0, "你好 = ni hao。"),
		_make_question("py_easy_2", "拼音", "easy", "“谢谢”的拼音是哪一个？", ["qing wen", "xie xie", "lao shi", "peng you"], 1, "谢谢 = xie xie。"),
		_make_question("py_medium_1", "拼音", "medium", "“老师”的正确拼音是？", ["lao shi", "luo si", "la shi", "liang shi"], 0, "老师 = lao shi。"),
		_make_question("py_medium_2", "拼音", "medium", "“中国”的正确拼音是？", ["zhong guo", "zhong gua", "zong guo", "cheng guo"], 0, "中国 = zhong guo。"),
		_make_question("py_hard_1", "拼音", "hard", "“北京二中”的拼音更接近哪一个？", ["bei jing er zhong", "bai jing yi zhong", "bei jin er zong", "bei qing er zhong"], 0, "北京二中 = bei jing er zhong。"),
		_make_question("py_hard_2", "拼音", "hard", "“中文社”的拼音是？", ["zhong wen she", "zhong wen se", "zong wen she", "cheng wen she"], 0, "中文社 = zhong wen she。"),

		_make_question("voc_easy_1", "词汇", "easy", "“水”是什么意思？", ["water", "fire", "school", "card"], 0, "水 = water。"),
		_make_question("voc_easy_2", "词汇", "easy", "“朋友”是什么意思？", ["teacher", "friend", "monster", "answer"], 1, "朋友 = friend。"),
		_make_question("voc_medium_1", "词汇", "medium", "“教室”是什么意思？", ["classroom", "library", "office", "gym"], 0, "教室 = classroom。"),
		_make_question("voc_medium_2", "词汇", "medium", "“迟到”是什么意思？", ["to arrive late", "to study", "to win", "to ask"], 0, "迟到 = to arrive late。"),
		_make_question("voc_hard_1", "词汇", "hard", "“吉祥物”是什么意思？", ["mascot", "homework", "culture", "question"], 0, "吉祥物 = mascot。"),
		_make_question("voc_hard_2", "词汇", "hard", "“减伤”在游戏里更接近？", ["damage reduction", "extra gold", "new level", "random card"], 0, "减伤 = damage reduction。"),

		_make_question("cul_easy_1", "文化", "easy", "春节通常和哪种颜色关系最密切？", ["红色", "蓝色", "黑色", "紫色"], 0, "春节常用红色表达喜庆。"),
		_make_question("cul_easy_2", "文化", "easy", "中秋节常吃什么？", ["月饼", "饺子", "粽子", "面条"], 0, "中秋节常吃月饼。"),
		_make_question("cul_medium_1", "文化", "medium", "清明节常见活动是？", ["扫墓", "贴春联", "吃月饼", "赛龙舟"], 0, "清明节常见活动包括扫墓。"),
		_make_question("cul_medium_2", "文化", "medium", "端午节常见食物是？", ["粽子", "月饼", "汤圆", "蛋糕"], 0, "端午节常吃粽子。"),
		_make_question("cul_hard_1", "文化", "hard", "“中文社”最可能推广的是？", ["中文学习和中国文化", "化学实验", "足球训练", "机器人维修"], 0, "中文社围绕中文学习和文化交流。"),
		_make_question("cul_hard_2", "文化", "hard", "春节贴春联通常表达什么？", ["祝福和新年愿望", "考试答案", "地图路线", "购物清单"], 0, "春联常表达祝福与新年愿望。")
	]
	for question: QuestionData in questions:
		_assign_translation_keys(question)


func _question_from_dictionary(data: Dictionary) -> QuestionData:
	var question := QuestionData.new()
	question.id = str(data.get("id", ""))
	question.category = str(data.get("category", ""))
	question.difficulty = str(data.get("difficulty", "easy"))
	question.prompt = str(data.get("prompt", ""))
	question.explanation = str(data.get("explanation", ""))
	question.correct_index = int(data.get("correct_index", 0))

	var raw_options_value: Variant = data.get("options", [])
	if not raw_options_value is Array:
		return null

	var raw_options: Array = raw_options_value
	var typed_options: Array[String] = []
	for option: Variant in raw_options:
		typed_options.append(str(option))
	question.options = typed_options

	if question.id == "" or question.category == "" or question.prompt == "" or question.options.size() < 2:
		return null
	if question.correct_index < 0 or question.correct_index >= question.options.size():
		return null

	_assign_translation_keys(question)
	return question


func _assign_translation_keys(question: QuestionData) -> void:
	# JSON 保存原文，运行时使用稳定键从 translations.csv 取得当前语言文本。
	var translation_prefix: String = "Q_%s" % question.id.to_upper()
	question.prompt = "%s_PROMPT" % translation_prefix
	question.explanation = "%s_EXPLANATION" % translation_prefix
	for option_index in question.options.size():
		question.options[option_index] = "%s_O%d" % [translation_prefix, option_index]


func _make_question(id: String, category: String, difficulty: String, prompt: String, options: Array, correct_index: int, explanation: String) -> QuestionData:
	var question := QuestionData.new()
	question.id = id
	question.category = category
	question.difficulty = difficulty
	question.prompt = prompt
	var typed_options: Array[String] = []
	for option: String in options:
		typed_options.append(option)
	question.options = typed_options
	question.correct_index = correct_index
	question.explanation = explanation
	return question
