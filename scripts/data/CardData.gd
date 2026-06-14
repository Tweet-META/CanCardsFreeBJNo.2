extends Resource
class_name CardData

enum CardType {
	ATTACK,
	DEFENSE,
	SKILL,
	GENERAL
}

enum TargetType {
	SELF,
	SINGLE_ENEMY,
	ALL_ENEMIES,
	ALL_ALLIES
}

@export var id: String = ""
@export var display_name: String = ""
@export_multiline var description: String = ""
@export var owner_id: String = ""
@export var card_type: CardType = CardType.ATTACK
@export var target_type: TargetType = TargetType.SINGLE_ENEMY
@export var required_attribute: String = ""
@export var requires_question: bool = true
@export var fixed_difficulty: String = ""
@export var base_damage: int = 0
@export var base_block: float = 0.0
@export var base_ap_gain: float = 0.5
@export var skill_ap_cost: float = 5.0
@export var clears_ap_on_use: bool = false
@export var art_path: String = ""
@export var shop_price: float = 0.0


func is_skill() -> bool:
	return card_type == CardType.SKILL


func is_general() -> bool:
	return card_type == CardType.GENERAL


func can_use(current_ap: float) -> bool:
	if is_skill():
		return current_ap >= skill_ap_cost
	return true


func get_question_difficulty(default_difficulty: String) -> String:
	if fixed_difficulty != "":
		return fixed_difficulty
	return default_difficulty


func get_damage_bonus_for_difficulty(difficulty: String) -> float:
	match difficulty:
		"easy":
			return 0.05
		"medium":
			return 0.07
		"hard":
			return 0.10
		_:
			return 0.0


func get_block_bonus_for_difficulty(difficulty: String) -> float:
	match difficulty:
		"easy":
			return 0.10
		"medium":
			return 0.15
		"hard":
			return 0.20
		_:
			return 0.0


func get_correct_answer_ap_bonus(difficulty: String) -> float:
	match difficulty:
		"easy":
			return 0.5
		"medium":
			return 0.7
		"hard":
			return 1.0
		_:
			return 0.0
