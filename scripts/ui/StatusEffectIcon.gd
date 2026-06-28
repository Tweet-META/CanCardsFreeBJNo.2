extends Control
## Defines the StatusEffectIcon script.
class_name StatusEffectIcon

@onready var icon: TextureRect = $Icon
@onready var overlay_icon: TextureRect = $OverlayIcon
@onready var value_label: Label = $ValueLabel
@onready var duration_label: Label = $DurationLabel


func setup(effect: StatusEffectData) -> void:
	if effect == null:
		hide()
		return
	show()
	var source_text: String = tr(effect.source_name) if not effect.source_name.is_empty() else tr("EFFECT_SOURCE_UNKNOWN")
	var effect_description: String = tr(effect.description)
	if effect.value_format == "percent":
		effect_description = effect_description % roundi(effect.value * 100.0)
	elif effect.value_format == "text" and effect_description.find("%s") != -1:
		effect_description = effect_description % tr(effect.detail_text)
	tooltip_text = tr("EFFECT_TOOLTIP_FORMAT") % [source_text, effect_description]
	if not effect.icon_path.is_empty() and ResourceLoader.exists(effect.icon_path):
		icon.texture = load(effect.icon_path) as Texture2D
	else:
		icon.texture = null
	if not effect.overlay_icon_path.is_empty() and ResourceLoader.exists(effect.overlay_icon_path):
		overlay_icon.texture = load(effect.overlay_icon_path) as Texture2D
		overlay_icon.visible = true
	else:
		overlay_icon.texture = null
		overlay_icon.visible = false
	match effect.value_format:
		"percent":
			value_label.text = "%d%%" % roundi(effect.value * 100.0)
		"integer":
			value_label.text = str(roundi(effect.value))
		"text":
			value_label.text = tr(effect.value_text)
		_:
			value_label.text = ""
	if effect.id == "damage_immunity":
		value_label.text = str(maxi(1, roundi(effect.value)))
	duration_label.text = str(effect.remaining_turns) if effect.show_duration else ""
