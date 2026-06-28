extends Label
## Defines the BattleInfoPanel script.
class_name BattleInfoPanel

const PAPER: Color = Color(0.86, 0.78, 0.64, 0.96)
const INK: Color = Color(0.12, 0.10, 0.08)


func _ready() -> void:
	_apply_export_safe_layout()
	add_theme_color_override("font_color", INK)
	add_theme_stylebox_override("normal", _style(PAPER, 8, 2))
	_update_typography()
	LanguageManager.language_changed.connect(_on_language_changed)


func _apply_export_safe_layout() -> void:
	anchor_left = 0.0
	anchor_top = 1.0
	anchor_right = 0.0
	anchor_bottom = 1.0
	offset_left = 26.0
	offset_top = -118.0
	offset_right = 216.0
	offset_bottom = -16.0
	grow_vertical = Control.GROW_DIRECTION_BEGIN


func _on_language_changed(_locale: String) -> void:
	_update_typography()


func _update_typography() -> void:
	var english: bool = TranslationServer.get_locale().begins_with("en")
	add_theme_font_size_override("font_size", 13 if english else 16)


func _style(color: Color, radius: int, border_width: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.corner_radius_top_left = radius
	style.corner_radius_top_right = radius
	style.corner_radius_bottom_left = radius
	style.corner_radius_bottom_right = radius
	style.border_width_left = border_width
	style.border_width_right = border_width
	style.border_width_top = border_width
	style.border_width_bottom = border_width
	style.border_color = Color(0.13, 0.10, 0.08)
	style.shadow_color = Color(0, 0, 0, 0.20)
	style.shadow_size = 5
	return style
