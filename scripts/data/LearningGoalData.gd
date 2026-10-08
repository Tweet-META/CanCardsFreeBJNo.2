extends Resource
## Stores one optional battle-wide learning goal selected before combat.
class_name LearningGoalData

@export var id: String = ""
@export var attribute: String = ""
@export var display_name: String = ""
@export var description: String = ""
@export var summary: String = ""
@export var team_stat_multiplier: float = 1.0
@export var wrong_answer_bonus_chance: float = 0.0
@export var ap_growth_bonus: float = 0.0
