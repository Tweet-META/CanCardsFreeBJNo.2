extends SceneTree
## 验证中英文 UI、卡牌与题目翻译键均可由 LanguageManager 解析。


func _init() -> void:
	var language_manager: Node = root.get_node_or_null("LanguageManager")
	if language_manager == null:
		push_error("LanguageManager autoload is missing.")
		quit(1)
		return

	language_manager.set_language("zh_CN", false)
	if tr("MENU_START") != "开始战斗":
		push_error("Chinese localization failed.")
		quit(1)
		return

	language_manager.set_language("en", false)
	if tr("MENU_START") != "Start Battle":
		push_error("English UI localization failed.")
		quit(1)
		return
	if tr("CARD_RABBIT_ATTACK") != "Pinyin Combo":
		push_error("English card localization failed.")
		quit(1)
		return
	if tr("Q_CUL_EASY_1_PROMPT") == "Q_CUL_EASY_1_PROMPT":
		push_error("English question localization failed.")
		quit(1)
		return

	language_manager.set_language("zh_CN", false)
	quit()
