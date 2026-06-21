extends Resource
## 单张卡牌的静态数据与通用规则；具体效果由 BattleManager 根据 effect_id 执行。
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


func is_skill() -> bool:
	return card_type == CardType.SKILL


func is_general() -> bool:
	return card_type == CardType.GENERAL


func can_use(current_ap: float) -> bool:
	if is_skill():
		return current_ap >= skill_ap_cost
	return true


func get_sell_price() -> float:
	# 出售价格为买入价的 60%，并向上取整到一位小数。
	return ceilf(shop_price * 0.6 * 10.0) / 10.0


func get_question_difficulty(default_difficulty: String) -> String:
	# 技能始终使用困难题，其余卡牌沿用玩家选择的难度。
	return "hard" if is_skill() else default_difficulty


func get_damage_bonus_for_difficulty(difficulty: String) -> float:
	# 普通攻击卡答对后的倍率加成。
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
	# 防御卡答对后叠加到基础减伤上的比例。
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
	# 答对后获得的额外队伍 AP，不包含卡牌基础 AP 与文化被动。
	match difficulty:
		"easy":
			return 0.5
		"medium":
			return 0.7
		"hard":
			return 1.0
		_:
			return 0.0
