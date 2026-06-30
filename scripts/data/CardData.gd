extends Resource
## Defines the CardData script.
class_name CardData

enum CardType {
	ATTACK,
	DEFENSE,
	SKILL,
	GENERAL
}

enum TargetType {
	SELF,
	SINGLE_ALLY,
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
@export var base_damage: int = 0
@export var base_block: float = 0.0
@export var base_ap_gain: float = 0.5
@export var skill_ap_cost: float = 5.0
@export var effect_id: String = ""
@export var status_effect_id: String = ""
@export var status_effect_value: float = 0.0
@export var status_effect_duration: int = 0
@export var status_effect_delay: int = 0
@export var secondary_status_effect_id: String = ""
@export var secondary_status_effect_value: float = 0.0
@export var secondary_status_effect_duration: int = 0
@export var secondary_status_effect_delay: int = 0
@export var current_hp_damage_ratio: float = 0.0
@export var max_hp_heal_ratio: float = 0.0
@export var direct_hp_loss: int = 0
@export var available_in_pool: bool = true
@export var art_path: String = ""
@export var shop_price: float = 0.0


## Is skill.
func is_skill() -> bool:
	return card_type == CardType.SKILL


## Is general.
func is_general() -> bool:
	return card_type == CardType.GENERAL


## Targets single enemy.
func targets_single_enemy() -> bool:
	return target_type == TargetType.SINGLE_ENEMY


## Targets ally.
func targets_ally() -> bool:
	return card_type == CardType.DEFENSE or target_type == TargetType.SINGLE_ALLY


## Can use.
func can_use(current_ap: float) -> bool:
	if is_skill():
		return current_ap >= skill_ap_cost
	return true


## Get sell price.
func get_sell_price() -> float:
	return ceilf(shop_price * 0.6 * 10.0) / 10.0


## Get question difficulty.
func get_question_difficulty(default_difficulty: String) -> String:
	return "hard" if is_skill() else default_difficulty


## Get damage bonus for difficulty.
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


## Get block bonus for difficulty.
func get_block_bonus_for_difficulty(difficulty: String) -> float:
	match difficulty:
		"easy":
			return 0.02
		"medium":
			return 0.03
		"hard":
			return 0.05
		_:
			return 0.0


## Get correct answer ap bonus.
func get_correct_answer_ap_bonus(difficulty: String) -> float:
	match difficulty:
		"easy":
			return 0.2
		"medium":
			return 0.3
		"hard":
			return 0.5
		_:
			return 0.0
