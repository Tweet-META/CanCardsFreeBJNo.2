extends CanvasLayer
## Keeps the iris visible across scene changes and loads JSON resources in the background.

@export_range(0.05, 2.0, 0.05) var close_duration: float = 0.4
@export_range(0.05, 2.0, 0.05) var reveal_duration: float = 0.45

@onready var root: Control = $Root
@onready var input_blocker: Control = $Root/InputBlocker
@onready var loading_screen: LoadingScreen = $Root/LoadingScreen
@onready var iris: ColorRect = $Root/Iris

var _busy: bool = false
var _loading: bool = false
var _level: LevelData
var _source_scene: Node
var _source_process_mode: Node.ProcessMode = Node.PROCESS_MODE_INHERIT
var _paths: PackedStringArray = []
var _weights: PackedFloat32Array = []
var _index: int = 0
var _completed_work: float = 0.0
var _total_work: float = 0.0
var _packed_scene: PackedScene
var _retained_resources: Array[Resource] = []
var _loaded_scene_path: String = ""
var _returning: bool = false


## Initializes the persistent overlay without covering the current scene.
func _ready() -> void:
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.resized.connect(_update_aspect)
	loading_screen.retry_requested.connect(_retry)
	loading_screen.back_requested.connect(_return_to_source)
	get_tree().scene_changed.connect(_release_previous_resources)
	_update_aspect()
	set_process(false)
	hide()


## Prevents duplicate requests from changing the selected party during a transition.
func is_busy() -> bool:
	return _busy


## Closes the map, reveals the loading picture, then begins threaded resource requests.
func enter_level(level: LevelData) -> void:
	if _busy or level == null:
		return
	_busy = true
	_level = level
	_source_scene = get_tree().current_scene
	if is_instance_valid(_source_scene):
		_source_process_mode = _source_scene.process_mode
		_source_scene.process_mode = Node.PROCESS_MODE_DISABLED
	loading_screen.hide()
	show()
	input_blocker.grab_focus()
	await _animate_iris(0.0, close_duration)
	loading_screen.reset_progress()
	loading_screen.show()
	await _animate_iris(1.0, reveal_duration)
	_begin_loading()


## Builds a dependency-weighted work queue and retains resources for later battle reuse.
func _begin_loading() -> void:
	_retained_resources.clear()
	_packed_scene = null
	_loaded_scene_path = ""
	_paths = LevelResourceManifest.collect(_level)
	_weights.clear()
	_total_work = 0.0
	_completed_work = 0.0
	_index = 0
	for path: String in _paths:
		var weight: float = float(ResourceLoader.get_dependencies(path).size() + 1)
		_weights.append(weight)
		_total_work += weight
	loading_screen.reset_progress()
	_request_next()


## Requests one resource without blocking the main thread on its load result.
func _request_next() -> void:
	if _index >= _paths.size():
		_loading = false
		set_process(false)
		loading_screen.set_progress(1.0)
		_finish_loading()
		return
	var error: Error = ResourceLoader.load_threaded_request(_paths[_index], "", false, ResourceLoader.CACHE_MODE_REUSE)
	if error != OK:
		_fail_loading(_paths[_index])
		return
	_loading = true
	set_process(true)


## Polls Godot once per frame; only retrieves results after THREAD_LOAD_LOADED.
func _process(_delta: float) -> void:
	if not _loading:
		return
	var progress: Array = []
	var path: String = _paths[_index]
	var status: ResourceLoader.ThreadLoadStatus = ResourceLoader.load_threaded_get_status(path, progress)
	var fraction: float = float(progress[0]) if not progress.is_empty() else 0.0
	loading_screen.set_progress((_completed_work + fraction * _weights[_index]) / maxf(_total_work, 1.0))
	match status:
		ResourceLoader.THREAD_LOAD_LOADED:
			var resource: Resource = ResourceLoader.load_threaded_get(path)
			if resource == null:
				_fail_loading(path)
				return
			_retained_resources.append(resource)
			if path == _level.scene_path:
				_packed_scene = resource as PackedScene
			_completed_work += _weights[_index]
			_index += 1
			_request_next()
		ResourceLoader.THREAD_LOAD_FAILED, ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
			_fail_loading(path)


## Switches scenes under black and waits for the battle's first complete UI refresh.
func _finish_loading() -> void:
	if _packed_scene == null:
		_fail_loading(_level.scene_path)
		return
	await _animate_iris(0.0, close_duration)
	var error: Error = get_tree().change_scene_to_packed(_packed_scene)
	if error != OK:
		await _animate_iris(1.0, reveal_duration)
		_fail_loading(_level.scene_path)
		return
	await get_tree().scene_changed
	var destination: Node = get_tree().current_scene
	var destination_mode: Node.ProcessMode = destination.process_mode
	destination.process_mode = Node.PROCESS_MODE_DISABLED
	if destination.has_signal(&"loading_ready") and not bool(destination.get(&"loading_ready_complete")):
		await Signal(destination, &"loading_ready")
	await get_tree().process_frame
	loading_screen.hide()
	_loaded_scene_path = _level.scene_path
	await _animate_iris(1.0, reveal_duration)
	destination.process_mode = destination_mode
	_source_scene = null
	_busy = false
	hide()


## Reports resource failure without replacing the still-recoverable source scene.
func _fail_loading(path: String) -> void:
	_loading = false
	set_process(false)
	push_error("SceneTransition: could not load '%s'." % path)
	loading_screen.show_failure()


## Reuses the selected level and party after an explicit retry.
func _retry() -> void:
	if _busy and not _loading and not _returning:
		_begin_loading()


## Restores the original map after a failed request.
func _return_to_source() -> void:
	if not _busy or _loading or _returning:
		return
	_returning = true
	loading_screen.actions.hide()
	await _animate_iris(0.0, close_duration)
	loading_screen.hide()
	_retained_resources.clear()
	_packed_scene = null
	if is_instance_valid(_source_scene):
		_source_scene.process_mode = _source_process_mode
	await _animate_iris(1.0, reveal_duration)
	_busy = false
	_returning = false
	hide()


## Animates only the presentation mask, never the loading progress.
func _animate_iris(aperture: float, duration: float) -> void:
	var material: ShaderMaterial = iris.material as ShaderMaterial
	var tween: Tween = create_tween()
	tween.tween_property(material, "shader_parameter/aperture", aperture, duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await tween.finished


## Keeps the circular opening round at different viewport aspect ratios.
func _update_aspect() -> void:
	var material: ShaderMaterial = iris.material as ShaderMaterial
	material.set_shader_parameter("screen_aspect", root.size.x / maxf(root.size.y, 1.0))


## Keeps future wave textures cached until the loaded battle is left.
func _release_previous_resources() -> void:
	if _busy or _loaded_scene_path.is_empty():
		return
	var current: Node = get_tree().current_scene
	if current == null or current.scene_file_path != _loaded_scene_path:
		_retained_resources.clear()
		_packed_scene = null
		_loaded_scene_path = ""
