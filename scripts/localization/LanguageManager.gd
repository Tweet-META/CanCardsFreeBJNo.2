extends Node
## 从单个 CSV 构建运行时翻译资源，并持久化当前语言。

signal language_changed(locale: String)

const TRANSLATIONS_PATH: String = "res://data/localization/translations.csv"
const SETTINGS_PATH: String = "user://settings.cfg"
const SUPPORTED_LOCALES: Array[String] = ["zh_CN", "en"]
const DEFAULT_LOCALE: String = "zh_CN"


func _ready() -> void:
	_load_translations()
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


func _load_translations() -> void:
	# CSV 第一列是 key，后续每列对应表头中的 locale。
	var file: FileAccess = FileAccess.open(TRANSLATIONS_PATH, FileAccess.READ)
	if file == null:
		push_error("Unable to open localization file: %s" % TRANSLATIONS_PATH)
		return

	var headers: PackedStringArray = file.get_csv_line()
	if headers.size() < 2 or headers[0] != "key":
		push_error("Localization CSV must start with a key column.")
		return

	var translations: Dictionary = {}
	for column in range(1, headers.size()):
		var locale: String = headers[column].strip_edges()
		if locale == "":
			continue
		var translation := Translation.new()
		translation.locale = locale
		translations[column] = translation

	while not file.eof_reached():
		var row: PackedStringArray = file.get_csv_line()
		if row.is_empty():
			continue
		var key: String = row[0].strip_edges()
		if key == "":
			continue
		for column: int in translations:
			if column < row.size():
				var translation: Translation = translations[column]
				translation.add_message(key, row[column])

	for translation: Translation in translations.values():
		TranslationServer.add_translation(translation)
