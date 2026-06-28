extends Node
## Stores global settings and broadcasts developer-mode changes.

signal developer_mode_changed(enabled: bool)

const SETTINGS_PATH: String = "user://settings.cfg"

var developer_mode: bool = false


## Loads the saved developer-mode state after the autoload is ready.
func _ready() -> void:
	developer_mode = bool(get_setting_value("developer", "enabled", false))


## Toggles developer mode when F1 is pressed.
func _input(event: InputEvent) -> void:
	var key_event: InputEventKey = event as InputEventKey
	if key_event == null:
		return
	if key_event.pressed and not key_event.echo and key_event.keycode == KEY_F1:
		set_developer_mode(not developer_mode)


## Sets and persists developer mode only when the value actually changes.
func set_developer_mode(enabled: bool) -> void:
	if developer_mode == enabled:
		return
	developer_mode = enabled
	set_setting_value("developer", "enabled", developer_mode)
	developer_mode_changed.emit(developer_mode)


## Reads a setting value through the same repair path used by all settings.
func get_setting_value(section: String, key: String, default_value: Variant) -> Variant:
	var config: ConfigFile = _load_settings_config()
	if config == null:
		return default_value
	return config.get_value(section, key, default_value)


## Writes a setting value while preserving any other valid settings.
func set_setting_value(section: String, key: String, value: Variant) -> void:
	var config: ConfigFile = _load_settings_config()
	if config == null:
		config = ConfigFile.new()
	config.set_value(section, key, value)
	config.save(SETTINGS_PATH)


## Loads settings; if NUL bytes exist, discards the corrupted file.
func _load_settings_config() -> ConfigFile:
	if FileAccess.file_exists(SETTINGS_PATH):
		var file: FileAccess = FileAccess.open(SETTINGS_PATH, FileAccess.READ)
		if file != null:
			var bytes: PackedByteArray = file.get_buffer(file.get_length())
			if bytes.find(0) != -1:
				var repaired_config: ConfigFile = ConfigFile.new()
				repaired_config.save(SETTINGS_PATH)
				return repaired_config

	var config: ConfigFile = ConfigFile.new()
	if config.load(SETTINGS_PATH) != OK:
		return null
	return config
