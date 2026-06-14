extends Resource
class_name EnemyData

@export var id: String = ""
@export var display_name: String = ""
@export var attribute: String = ""
@export var max_hp: int = 80
@export var attack: int = 12
@export var defense: int = 2
@export var toefl_reward: float = 1.0
@export var portrait_path: String = ""

var current_hp: int = 80


func setup_runtime() -> void:
	current_hp = max_hp


func is_alive() -> bool:
	return current_hp > 0


func take_damage(raw_damage: int) -> int:
	var final_damage: int = maxi(1, raw_damage - defense)
	current_hp = maxi(0, current_hp - final_damage)
	return final_damage


func get_basic_attack_damage() -> int:
	return maxi(1, attack)
