extends Control

@onready var start_button: Button = $CenterBox/StartButton
@onready var quit_button: Button = $CenterBox/QuitButton


func _ready() -> void:
	start_button.pressed.connect(_on_start_pressed)
	quit_button.pressed.connect(func() -> void: get_tree().quit())


func _on_start_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/BattleScene.tscn")
