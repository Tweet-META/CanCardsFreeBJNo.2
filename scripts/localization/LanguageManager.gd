extends Node
## 切换并持久化当前语言；翻译资源由 project.godot 原生注册。

signal language_changed(locale: String)

const SETTINGS_PATH: String = "user://settings.cfg"
const SUPPORTED_LOCALES: Array[String] = ["zh_CN", "en"]
const DEFAULT_LOCALE: String = "zh_CN"


func _ready() -> void:
	set_language(_load_saved_locale(), false)


func set_language(locale: String, save: bool = true) -> void:
	# 不支持的语言统一回退到中文，避免 TranslationServer 进入未知状态。
	var resolved_locale: String = locale if locale in SUPPORTED_LOCALES else DEFAULT_LOCALE
	TranslationServer.set_locale(resolved_locale)
	if save:
		var config := ConfigFile.new()
		config.load(SETTINGS_PATH)
		config.set_value("localization", "locale", resolved_locale)
		config.save(SETTINGS_PATH)
	language_changed.emit(resolved_locale)


func get_language() -> String:
	var locale: String = TranslationServer.get_locale()
	return locale if locale in SUPPORTED_LOCALES else DEFAULT_LOCALE


func _load_saved_locale() -> String:
	var config := ConfigFile.new()
	if config.load(SETTINGS_PATH) != OK:
		return DEFAULT_LOCALE
	return str(config.get_value("localization", "locale", DEFAULT_LOCALE))
