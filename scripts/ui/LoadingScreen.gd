extends Control
## Displays actual resource progress beneath an editor-owned placeholder image.
class_name LoadingScreen

signal retry_requested
signal back_requested

@onready var status_label: Label = $Footer/Content/Status
@onready var progress_bar: ProgressBar = $Footer/Content/Progress
@onready var percentage_label: Label = $Footer/Content/Percentage
@onready var actions: HBoxContainer = $Footer/Content/Actions
@onready var retry_button: Button = $Footer/Content/Actions/Retry
@onready var back_button: Button = $Footer/Content/Actions/Back

var failed: bool = false


## Connects recovery controls and keeps status text localized.
func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	retry_button.pressed.connect(func() -> void: retry_requested.emit())
	back_button.pressed.connect(func() -> void: back_requested.emit())
	LanguageManager.language_changed.connect(_refresh_language)
	reset_progress()


## Starts a new real loading attempt without a simulated progress tween.
func reset_progress() -> void:
	failed = false
	actions.hide()
	set_progress(0.0)


## Updates the bar directly from the loader's measured completion fraction.
func set_progress(fraction: float) -> void:
	progress_bar.value = clampf(fraction, 0.0, 1.0) * 100.0
	_refresh_language()


## Offers explicit recovery when a resource cannot be loaded.
func show_failure() -> void:
	failed = true
	actions.show()
	retry_button.grab_focus()
	_refresh_language()


## Refreshes labels while preserving the measured progress value.
func _refresh_language(_locale: String = "") -> void:
	status_label.text = tr("LOADING_FAILED" if failed else ("LOADING_COMPLETE" if progress_bar.value >= 100.0 else "LOADING_STATUS"))
	percentage_label.text = tr("LOADING_PERCENT_FORMAT") % floori(progress_bar.value)
	retry_button.text = tr("LOADING_RETRY")
	back_button.text = tr("LOADING_BACK")
