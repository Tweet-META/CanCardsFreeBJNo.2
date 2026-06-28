extends RefCounted
## Defines the LearningAttribute script.
class_name LearningAttribute

const PINYIN: String = "拼音"
const VOCABULARY: String = "词汇"
const CULTURE: String = "文化"


static func from_id(attribute_id: String) -> String:
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
