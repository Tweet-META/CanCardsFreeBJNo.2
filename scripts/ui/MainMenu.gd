extends Control


func _ready() -> void:
	_build_ui()


func _build_ui() -> void:
	var background := ColorRect.new()
	background.color = Color(0.09, 0.10, 0.11)
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(background)

	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_CENTER)
	box.custom_minimum_size = Vector2(560, 320)
	box.position = Vector2(-280, -160)
	box.add_theme_constant_override("separation", 18)
	add_child(box)

	var title := Label.new()
	title.text = "Can Cards Free BJNo.2?"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 42)
	box.add_child(title)

	var subtitle := Label.new()
	subtitle.text = "中文社吉祥物卡牌 RPG - MVP"
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_font_size_override("font_size", 22)
	box.add_child(subtitle)

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(1, 36)
	box.add_child(spacer)

	var start_button := Button.new()
	start_button.text = "开始战斗"
	start_button.custom_minimum_size = Vector2(280, 58)
	start_button.pressed.connect(_on_start_pressed)
	box.add_child(start_button)

	var quit_button := Button.new()
	quit_button.text = "退出"
	quit_button.custom_minimum_size = Vector2(280, 48)
	quit_button.pressed.connect(func() -> void: get_tree().quit())
	box.add_child(quit_button)


func _on_start_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/BattleScene.tscn")
