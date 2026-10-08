extends PanelContainer
## Defines the BattleLogPanel script.
class_name BattleLogPanel
signal log_opened()

@onready var collapsed_label: Label = $LogStack/CollapsedLabel
@onready var close_button: Button = $LogStack/CloseButton
@onready var log_label: RichTextLabel = $LogStack/LogLabel

@export var collapsed_size: Vector2 = Vector2(64, 64)
@export var expanded_size: Vector2 = Vector2(250, 190)
@export var tutorial_expanded_size: Vector2 = Vector2(360, 260)
@export var size_tween_duration: float = 0.16

var expanded: bool = false
var size_tween: Tween
var tutorial_mode: bool = false


## Initializes the collapsed log panel and connects its local controls.
func _ready() -> void:
	custom_minimum_size = collapsed_size
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	gui_input.connect(_on_gui_input)
	close_button.pressed.connect(collapse)


func set_messages(messages: Array[String]) -> void:
	log_label.clear()
	for message: String in messages:
		log_label.append_text(message + "\n")


## Expands the log while preserving its existing message contents.
func expand() -> void:
	if expanded:
		return
	expanded = true
	collapsed_label.visible = false
	close_button.visible = true
	log_label.visible = true
	_tween_size(tutorial_expanded_size if tutorial_mode else expanded_size)
	log_opened.emit()


## Gives the first tutorial enough reading space without changing normal battle logs.
func set_tutorial_mode(enabled: bool) -> void:
	if tutorial_mode == enabled:
		return
	tutorial_mode = enabled
	if expanded:
		_tween_size(tutorial_expanded_size if tutorial_mode else expanded_size)


## Collapses the log back to its editor-configured compact size.
func collapse() -> void:
	if not expanded:
		return
	expanded = false
	log_label.visible = false
	close_button.visible = false
	collapsed_label.visible = true
	_tween_size(collapsed_size)


func _on_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		expand()
		accept_event()


## Animates between the inspector-owned collapsed and expanded sizes.
func _tween_size(target_size: Vector2) -> void:
	if size_tween != null and size_tween.is_running():
		size_tween.kill()
	size_tween = create_tween()
	size_tween.set_ease(Tween.EASE_OUT)
	size_tween.set_trans(Tween.TRANS_CUBIC)
	size_tween.tween_property(self, "custom_minimum_size", target_size, size_tween_duration)
