extends SceneTree
## 验证独立覆盖面板在不同视口尺寸下仍使用锚点定位，而不是退回左上角。


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var packed_scene: PackedScene = load("res://scenes/ui/BattleUI.tscn") as PackedScene
	assert(packed_scene != null)
	var battle_ui: BattleUI = packed_scene.instantiate() as BattleUI
	root.add_child(battle_ui)
	battle_ui.size = Vector2(2000, 1125)
	await process_frame

	var info_panel: BattleInfoPanel = battle_ui.get_node("BattleInfoPanel") as BattleInfoPanel
	var developer_panel: DeveloperControls = battle_ui.get_node("DeveloperControls") as DeveloperControls
	var shop_panel: ShopPanel = battle_ui.get_node("ShopPanel") as ShopPanel
	assert(info_panel.position.x > 0.0)
	assert(info_panel.position.y > battle_ui.size.y * 0.70)
	assert(developer_panel.position.x > battle_ui.size.x * 0.20)
	assert(developer_panel.position.x < battle_ui.size.x * 0.60)
	assert(developer_panel.position.y > 0.0)
	assert(absf(shop_panel.position.x + shop_panel.size.x * 0.5 - battle_ui.size.x * 0.5) < 1.0)
	assert(absf(shop_panel.position.y + shop_panel.size.y * 0.5 - battle_ui.size.y * 0.5) < 1.0)

	var menu_scene: PackedScene = load("res://scenes/MainMenu.tscn") as PackedScene
	assert(menu_scene != null)
	var main_menu: Control = menu_scene.instantiate() as Control
	root.add_child(main_menu)
	main_menu.size = Vector2(2000, 1125)
	await process_frame
	var settings_panel: SettingsPanel = main_menu.get_node("SettingsPanel") as SettingsPanel
	assert(absf(settings_panel.position.x + settings_panel.size.x * 0.5 - main_menu.size.x * 0.5) < 1.0)
	assert(absf(settings_panel.position.y + settings_panel.size.y * 0.5 - main_menu.size.y * 0.5) < 1.0)

	quit()
