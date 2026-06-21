extends SceneTree
## 验证地图数据、缺失图片回退和主地图场景能够安全实例化。


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	MapDatabase.reload()
	StageDatabase.reload()
	var floors: Array[MapFloorData] = MapDatabase.get_floors()
	assert(floors.size() == 1)
	assert(floors[0].id == "first_floor")
	assert(floors[0].image_path == "res://assets/ui/first_floor.png")
	assert(floors[0].unlocked)
	assert(floors[0].stage_ids == ["first_stage"])

	var first_stage: StageData = StageDatabase.create_stage("first_stage")
	assert(first_stage != null)
	assert(first_stage.floor_id == "first_floor")
	assert(first_stage.scene_path == "res://scenes/BattleScene.tscn")
	assert(first_stage.marker_text == "1")
	assert(first_stage.battle_background == "res://assets/ui/conversation_room.png")
	assert(first_stage.waves.size() == 1)
	assert(first_stage.waves[0].monster_slots.size() == 3)
	assert(first_stage.waves[0].monster_slots[0].candidate_enemy_ids == ["pinyin_bun"])
	assert(first_stage.unlocked)

	var packed_scene: PackedScene = load("res://scenes/MapScene.tscn") as PackedScene
	assert(packed_scene != null)
	var scene: MapScene = packed_scene.instantiate() as MapScene
	root.add_child(scene)
	await process_frame
	assert(scene.floors.size() == 1)
	assert(scene.floor_title.text == tr("MAP_FIRST_FLOOR"))
	assert(scene.map_texture.texture != null)
	assert(scene.stage_layer.get_child_count() == 1)
	assert(scene.stage_nodes.size() == 1)
	assert(scene.stage_nodes[0].stage_data.id == "first_stage")
	assert(scene.stage_nodes[0].stage_button.text == "1")

	quit()
