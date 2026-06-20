extends SceneTree
## 验证左下信息栏在长文本下固定底边，并只向上扩展。


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var packed_panel: PackedScene = load("res://scenes/ui/BattleInfoPanel.tscn")
	assert(packed_panel != null)
	var panel: BattleInfoPanel = packed_panel.instantiate() as BattleInfoPanel
	root.add_child(panel)
	await process_frame

	var initial_bottom: float = panel.position.y + panel.size.y
	var initial_height: float = panel.size.y
	panel.text = "第一行\n第二行很长，需要自动换行并增加高度。\n第三行\n第四行\n第五行\n第六行"
	await process_frame

	var expanded_bottom: float = panel.position.y + panel.size.y
	assert(panel.size.y > initial_height)
	assert(is_equal_approx(expanded_bottom, initial_bottom))
	quit()
