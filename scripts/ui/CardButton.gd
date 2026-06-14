extends Button
class_name CardButton

signal card_selected(card_index: int)
signal drag_started(card_index: int, global_position: Vector2)
signal drag_moved(global_position: Vector2)
signal drag_released(card_index: int, global_position: Vector2)
signal hover_changed(card_index: int, hovered: bool)

const CARD_BACK_PATH: String = "res://assets/cards/card_base_paper.png"
const LOCK_ICON_PATH: String = "res://assets/ui/skill_lock.png"

var card_index: int = -1
var drag_origin: Vector2 = Vector2.ZERO
var dragging: bool = false
var drag_ready: bool = false
var suppress_next_click: bool = false
var pose_tween: Tween
var focus_tween: Tween

var background: TextureRect
var art_texture: TextureRect
var title_label: Label
var body_label: Label
var lock_overlay: TextureRect
var lock_icon: TextureRect
var locked_by_ap: bool = false


func _ready() -> void:
	_ensure_visuals()


func setup(card: CardData, index: int, current_ap: float, enabled: bool) -> void:
	_ensure_visuals()
	card_index = index
	text = ""
	locked_by_ap = card.is_skill() and current_ap < card.skill_ap_cost
	disabled = not enabled or not card.can_use(current_ap)
	tooltip_text = card.description
	_update_text(card, current_ap)
	_update_art(card)
	_update_lock_state()
	_setup_style()
	if not pressed.is_connected(_on_pressed):
		pressed.connect(_on_pressed)
	if not mouse_entered.is_connected(_on_mouse_entered):
		mouse_entered.connect(_on_mouse_entered)
	if not mouse_exited.is_connected(_on_mouse_exited):
		mouse_exited.connect(_on_mouse_exited)


func _gui_input(event: InputEvent) -> void:
	if disabled:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			drag_origin = get_global_mouse_position()
			drag_ready = true
			dragging = false
		else:
			if dragging:
				drag_released.emit(card_index, get_global_mouse_position())
				suppress_next_click = true
				accept_event()
			drag_ready = false
			dragging = false
	elif event is InputEventMouseMotion and drag_ready:
		var current: Vector2 = get_global_mouse_position()
		if not dragging and drag_origin.distance_to(current) > 10.0:
			dragging = true
			drag_started.emit(card_index, drag_origin)
		if dragging:
			drag_moved.emit(current)
			accept_event()


func _on_pressed() -> void:
	if dragging or suppress_next_click:
		suppress_next_click = false
		return
	card_selected.emit(card_index)


func set_focus_state(focused: bool, dimmed: bool) -> void:
	var target_color: Color = Color.WHITE
	if locked_by_ap:
		target_color = Color(0.72, 0.72, 0.72, 1.0)
	elif focused:
		target_color = Color(1.06, 1.06, 1.06, 1.0)
	elif dimmed:
		target_color = Color(0.78, 0.78, 0.78, 0.86)

	if focus_tween != null and focus_tween.is_running():
		focus_tween.kill()
	focus_tween = create_tween()
	focus_tween.set_ease(Tween.EASE_OUT)
	focus_tween.set_trans(Tween.TRANS_CUBIC)
	focus_tween.tween_property(self, "modulate", target_color, 0.10)


func set_hand_pose(target_position: Vector2, target_rotation_degrees: float, target_scale: Vector2, target_z_index: int, animate: bool, duration: float = 0.14, delay: float = 0.0) -> void:
	z_index = target_z_index
	if pose_tween != null and pose_tween.is_running():
		pose_tween.kill()

	if not animate:
		position = target_position
		rotation_degrees = target_rotation_degrees
		scale = target_scale
		return

	pose_tween = create_tween()
	if delay > 0.0:
		pose_tween.tween_interval(delay)
	pose_tween.set_parallel(true)
	pose_tween.set_ease(Tween.EASE_OUT)
	pose_tween.set_trans(Tween.TRANS_CUBIC)
	pose_tween.tween_property(self, "position", target_position, duration)
	pose_tween.tween_property(self, "rotation_degrees", target_rotation_degrees, duration)
	pose_tween.tween_property(self, "scale", target_scale, duration)


func reset_drag_state() -> void:
	drag_ready = false
	dragging = false
	suppress_next_click = false


func _on_mouse_entered() -> void:
	if not dragging:
		hover_changed.emit(card_index, true)


func _on_mouse_exited() -> void:
	if not dragging:
		hover_changed.emit(card_index, false)


func _ensure_visuals() -> void:
	if background != null:
		return

	clip_contents = false
	mouse_filter = Control.MOUSE_FILTER_STOP

	background = TextureRect.new()
	background.texture = load(CARD_BACK_PATH)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	background.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	add_child(background)

	art_texture = TextureRect.new()
	art_texture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	art_texture.anchor_left = 0.18
	art_texture.anchor_top = 0.10
	art_texture.anchor_right = 0.82
	art_texture.anchor_bottom = 0.56
	art_texture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art_texture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	add_child(art_texture)

	title_label = Label.new()
	title_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title_label.anchor_left = 0.10
	title_label.anchor_top = 0.58
	title_label.anchor_right = 0.90
	title_label.anchor_bottom = 0.73
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title_label.add_theme_font_size_override("font_size", 15)
	title_label.add_theme_color_override("font_color", Color(0.10, 0.08, 0.06))
	add_child(title_label)

	body_label = Label.new()
	body_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	body_label.anchor_left = 0.10
	body_label.anchor_top = 0.72
	body_label.anchor_right = 0.90
	body_label.anchor_bottom = 0.92
	body_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	body_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	body_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body_label.add_theme_font_size_override("font_size", 13)
	body_label.add_theme_color_override("font_color", Color(0.12, 0.10, 0.08))
	add_child(body_label)

	lock_overlay = TextureRect.new()
	lock_overlay.visible = false
	lock_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lock_overlay.texture = load(CARD_BACK_PATH)
	lock_overlay.modulate = Color(0.08, 0.08, 0.08, 0.38)
	lock_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	lock_overlay.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	lock_overlay.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	add_child(lock_overlay)

	lock_icon = TextureRect.new()
	lock_icon.visible = false
	lock_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lock_icon.texture = load(LOCK_ICON_PATH)
	lock_icon.anchor_left = 0.31
	lock_icon.anchor_top = 0.22
	lock_icon.anchor_right = 0.69
	lock_icon.anchor_bottom = 0.48
	lock_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	lock_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	add_child(lock_icon)


func _update_text(card: CardData, current_ap: float) -> void:
	title_label.text = card.display_name
	if card.is_skill():
		body_label.text = "消耗 AP %.0f\n基础技能效果" % card.skill_ap_cost
	elif card.is_general():
		body_label.text = "全队获得\n+%.1f AP" % card.base_ap_gain
	elif card.card_type == CardData.CardType.ATTACK:
		body_label.text = "造成 %d 伤害\n答对强化" % card.base_damage
	elif card.card_type == CardData.CardType.DEFENSE:
		body_label.text = "获得 %.0f%% 减伤\n答对强化" % (card.base_block * 100.0)
	else:
		body_label.text = card.description


func _update_art(card: CardData) -> void:
	if card.art_path != "":
		art_texture.texture = load(card.art_path)


func _update_lock_state() -> void:
	lock_overlay.visible = locked_by_ap
	lock_icon.visible = locked_by_ap
	if locked_by_ap:
		modulate = Color(0.72, 0.72, 0.72, 1.0)
	else:
		modulate = Color.WHITE


func _setup_style() -> void:
	var empty_style := StyleBoxEmpty.new()
	add_theme_stylebox_override("normal", empty_style)
	add_theme_stylebox_override("hover", empty_style)
	add_theme_stylebox_override("pressed", empty_style)
	add_theme_stylebox_override("disabled", empty_style)
	add_theme_color_override("font_color", Color.TRANSPARENT)
	add_theme_color_override("font_disabled_color", Color.TRANSPARENT)
