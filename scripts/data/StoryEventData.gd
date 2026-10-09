extends Resource
## Defines a level-clear sequence slot and its localized fallback dialogue.
class_name StoryEventData

var id: String = ""
var level_id: String = ""
var sprite_frames_path: String = ""
var animation: StringName = &"story"
var speaker_name: String = ""
var portrait_path: String = ""
var dialogue_keys: Array[String] = []
var unlock_character_ids: Array[String] = []
var unlock_general_cards: bool = false
