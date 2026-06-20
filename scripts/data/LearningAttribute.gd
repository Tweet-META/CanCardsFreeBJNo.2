extends RefCounted
## 中文学习属性的唯一内部定义，并负责把 JSON 中的英文 ID 转成运行时值。
class_name LearningAttribute

const PINYIN: String = "拼音"
const VOCABULARY: String = "词汇"
const CULTURE: String = "文化"


static func from_id(attribute_id: String) -> String:
	# JSON 使用稳定的 ASCII ID，界面和题库仍使用项目现有的中文属性值。
	match attribute_id:
		"pinyin":
			return PINYIN
		"vocabulary":
			return VOCABULARY
		"culture":
			return CULTURE
		"none", "":
			return ""
		_:
			push_error("LearningAttribute: unknown attribute '%s'." % attribute_id)
			return ""
