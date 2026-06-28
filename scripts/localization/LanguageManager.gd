extends Node
## Switches the active locale and persists it through SettingsManager.

signal language_changed(locale: String)

const SUPPORTED_LOCALES: Array[String] = ["zh_CN", "en"]
const DEFAULT_LOCALE: String = "zh_CN"


## Applies the saved locale once localization resources are registered.
func _ready() -> void:
	set_language(_load_saved_locale(), false)


## Sets the active language and optionally saves it for later launches.
func set_language(locale: String, save: bool = true) -> void:
	var resolved_locale: String = locale if locale in SUPPORTED_LOCALES else DEFAULT_LOCALE
	TranslationServer.set_locale(resolved_locale)
	if save:
		SettingsManager.set_setting_value("localization", "locale", resolved_locale)
	language_changed.emit(resolved_locale)


## Returns the current supported language, falling back to Chinese.
func get_language() -> String:
	var locale: String = TranslationServer.get_locale()
	return locale if locale in SUPPORTED_LOCALES else DEFAULT_LOCALE


## Reads the saved language without directly touching the config file.
func _load_saved_locale() -> String:
	return str(SettingsManager.get_setting_value("localization", "locale", DEFAULT_LOCALE))
