extends PanelContainer
## Defines the BattleLogPanel script.
class_name BattleLogPanel

const COLLAPSED_SIZE: Vector2 = Vector2(64, 64)
const EXPANDED_SIZE: Vector2 = Vector2(250, 190)
const PAPER: Color = Color(0.86, 0.78, 0.64, 0.96)
const INK: Color = Color(0.12, 0.10, 0.08)

@onready var collapsed_label: Label = $LogStack/CollapsedLabel
@onready var close_button: Button = $LogStack/CloseButton
@onready var log_label: RichTextLabel = $LogStack/LogLabel

var expanded: bool = false
var size_tween: Tween


func _ready() -> void:
	custom_minimum_size = COLLAPSED_SIZE
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	add_theme_stylebox_override("panel", _style(Color(0.91, 0.84, 0.70, 0.92), 8, 2))
	close_button.add_theme_stylebox_override("normal", _style(Color(0.94, 0.87, 0.72), 10, 2))
	close_button.add_theme_stylebox_override("hover", _style(Color(1.0, 0.78, 0.68), 10, 2))
	close_button.add_theme_color_override("font_color", INK)
	log_label.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
	gui_input.connect(_on_gui_input)
	close_button.pressed.connect(collapse)


func set_messages(messages: Array[String]) -> void:
	log_label.clear()
	for message: String in messages:
		log_label.append_text(message + "\n")


func expand() -> void:
	if expanded:
		return
	expanded = true
	collapsed_label.visible = false
	close_button.visible = true
	log_label.visible = true
	_tween_size(EXPANDED_SIZE)


func collapse() -> void:
	if not expanded:
		return
	expanded = false
	log_label.visible = false
	close_button.visible = false
	collapsed_label.visible = true
	_tween_size(COLLAPSED_SIZE)


func _on_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		expand()
		accept_event()


func _tween_size(target_size: Vector2) -> void:
	if size_tween != null and size_tween.is_running():
		size_tween.kill()
	size_tween = create_tween()
	size_tween.set_ease(Tween.EASE_OUT)
	size_tween.set_trans(Tween.TRANS_CUBIC)
	size_tween.tween_property(self, "custom_minimum_size", target_size, 0.16)


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
