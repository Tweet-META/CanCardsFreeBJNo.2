extends Node

signal developer_mode_changed(enabled: bool)

const SETTINGS_PATH: String = "user://settings.cfg"

var developer_mode: bool = false


func _ready() -> void:
	var config := ConfigFile.new()
	if config.load(SETTINGS_PATH) == OK:
		developer_mode = bool(config.get_value("developer", "enabled", false))


func set_developer_mode(enabled: bool) -> void:
	if developer_mode == enabled:
		return
	developer_mode = enabled
	var config := ConfigFile.new()
	config.load(SETTINGS_PATH)
	config.set_value("developer", "enabled", developer_mode)
	config.save(SETTINGS_PATH)
	developer_mode_changed.emit(developer_mode)
