extends Resource
class_name CharacterData

const MAX_AP: float = 5.0

@export var id: String = ""
@export var display_name: String = ""
@export var attribute: String = ""
@export var max_hp: int = 100
@export var attack: int = 20
@export var defense: int = 4
@export var portrait_path: String = ""
@export var cards: Array[CardData] = []

var current_hp: int = 100
var ap: float = 0.0
var has_acted: bool = false
var turn_damage_reduction: float = 0.0


func setup_runtime() -> void:
	current_hp = max_hp
	ap = 0.0
	has_acted = false
	turn_damage_reduction = 0.0


func is_alive() -> bool:
	return current_hp > 0


func add_ap(amount: float) -> void:
	ap = minf(MAX_AP, ap + maxf(amount, 0.0))


func clear_ap() -> void:
	ap = 0.0


func heal(amount: int) -> void:
	current_hp = mini(max_hp, current_hp + maxi(amount, 0))


func take_damage(raw_damage: int, incoming_attribute: String = "") -> int:
	var reduction: float = turn_damage_reduction
	if incoming_attribute == attribute:
		reduction += 0.20

	var reduced_damage: int = maxi(1, roundi(float(raw_damage) * (1.0 - clampf(reduction, 0.0, 0.85))))
	var final_damage: int = maxi(1, reduced_damage - defense)
	current_hp = maxi(0, current_hp - final_damage)
	return final_damage


func reset_turn_state() -> void:
	has_acted = false
	turn_damage_reduction = 0.0


func mark_acted() -> void:
	has_acted = true


func add_turn_damage_reduction(amount: float) -> void:
	turn_damage_reduction = clampf(turn_damage_reduction + amount, 0.0, 0.85)
