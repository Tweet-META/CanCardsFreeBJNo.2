extends Node
## 保存全局设置并广播开发者模式变化。

signal developer_mode_changed(enabled: bool)

const SETTINGS_PATH: String = "user://settings.cfg"

var developer_mode: bool = false


func _ready() -> void:
	var config := ConfigFile.new()
	if config.load(SETTINGS_PATH) == OK:
		developer_mode = bool(config.get_value("developer", "enabled", false))


func set_developer_mode(enabled: bool) -> void:
	# 只有实际变化时才写盘和发信号，避免 UI 同步造成重复回调。
	if developer_mode == enabled:
		return
	developer_mode = enabled
	var config := ConfigFile.new()
	config.load(SETTINGS_PATH)
	config.set_value("developer", "enabled", developer_mode)
	config.save(SETTINGS_PATH)
	developer_mode_changed.emit(developer_mode)
