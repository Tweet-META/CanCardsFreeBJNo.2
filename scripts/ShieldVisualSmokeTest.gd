extends SceneTree
## 验证双方护盾状态、固定盾耗尽和共用护盾场景的显示规则。


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var shield_scene: PackedScene = load("res://scenes/ui/ShieldVisual.tscn") as PackedScene
	assert(shield_scene != null)
	var shield_visual: ShieldVisual = shield_scene.instantiate() as ShieldVisual
	root.add_child(shield_visual)
	await process_frame

	shield_visual.setup(8, 0.0)
	assert(shield_visual.visible)
	assert(shield_visual.shield_label.text == "8")
	shield_visual.setup(0, 0.15)
	assert(shield_visual.visible)
	assert(shield_visual.shield_label.text == "15%")
	shield_visual.setup(8, 0.15)
	assert(shield_visual.shield_label.text == "8 | 15%")
	shield_visual.setup(0, 0.0)
	assert(not shield_visual.visible)

	var character: CharacterData = CharacterData.new()
	character.max_hp = 100
	character.setup_runtime()
	character.add_shield(5)
	assert(character.take_damage(5) == 0)
	assert(character.current_shield == 0)

	var enemy: EnemyData = EnemyData.new()
	enemy.max_hp = 100
	enemy.setup_runtime()
	enemy.add_damage_reduction(0.20)
	enemy.add_shield(8)
	assert(enemy.take_damage(10) == 0)
	assert(enemy.current_shield == 0)

	quit()
