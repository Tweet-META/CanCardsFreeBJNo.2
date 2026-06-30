extends Button
## Defines the CardButton script.
class_name CardButton

signal card_selected(card_index: int)
signal drag_started(card_index: int, global_position: Vector2)
signal drag_moved(global_position: Vector2)
signal drag_released(card_index: int, global_position: Vector2)
signal hover_changed(card_index: int, hovered: bool)

@onready var background: TextureRect = $Background
@onready var art_texture: TextureRect = $ArtTexture
@onready var title_label: Label = $TitleLabel
@onready var body_label: Label = $BodyLabel
@onready var lock_overlay: TextureRect = $LockOverlay
@onready var lock_icon: TextureRect = $LockIcon

var card_index: int = -1
var drag_origin: Vector2 = Vector2.ZERO
var dragging: bool = false
var drag_ready: bool = false
var suppress_next_click: bool = false
var pose_tween: Tween
var focus_tween: Tween

var locked_by_ap: bool = false
var interaction_locked: bool = false


func _ready() -> void:
	_setup_style()
	if not pressed.is_connected(_on_pressed):
		pressed.connect(_on_pressed)
	if not mouse_entered.is_connected(_on_mouse_entered):
		mouse_entered.connect(_on_mouse_entered)
	if not mouse_exited.is_connected(_on_mouse_exited):
		mouse_exited.connect(_on_mouse_exited)


func setup(card: CardData, index: int, current_ap: float, enabled: bool) -> void:
	card_index = index
	text = ""
	locked_by_ap = card.is_skill() and current_ap < card.skill_ap_cost
	disabled = not enabled or not card.can_use(current_ap)
	tooltip_text = tr(card.description)
	_update_text(card)
	_update_typography()
	_update_art(card)
	_update_lock_state()


func _gui_input(event: InputEvent) -> void:
	if disabled or interaction_locked:
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
	if interaction_locked or dragging or suppress_next_click:
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


func set_interaction_locked(locked: bool) -> void:
	interaction_locked = locked
	if interaction_locked:
		reset_drag_state()


func _on_mouse_entered() -> void:
	if not dragging and not interaction_locked:
		hover_changed.emit(card_index, true)


func _on_mouse_exited() -> void:
	if not dragging and not interaction_locked:
		hover_changed.emit(card_index, false)


func _update_text(card: CardData) -> void:
	title_label.text = tr(card.display_name)
	if card.is_skill():
		body_label.text = "%s\n%s" % [tr("CARD_SKILL_COST") % card.skill_ap_cost, tr("CARD_SKILL_BASE_EFFECT")]
	elif card.is_general():
		match card.effect_id:
			"gain_team_ap":
				body_label.text = "%s\n%s" % [tr("CARD_GENERAL_TEAM_GAIN"), tr("CARD_AP_FORMAT") % card.base_ap_gain]
			"damage_current_hp_percent":
				body_label.text = (tr("CARD_CURRENT_HP_DAMAGE") % roundi(card.current_hp_damage_ratio * 100.0)).replace("\\n", "\n")
			"apply_status_ally", "apply_status_enemy", "heal_max_hp_percent":
				body_label.text = tr(card.description).replace("\\n", "\n")
			_:
				body_label.text = tr(card.description).replace("\\n", "\n")
	elif card.card_type == CardData.CardType.ATTACK:
		body_label.text = "%s\n%s" % [tr("CARD_ATTACK_DAMAGE") % card.base_damage, tr("CARD_ANSWER_ENHANCE")]
	elif card.card_type == CardData.CardType.DEFENSE:
		body_label.text = "%s\n%s" % [tr("CARD_DEFENSE_REDUCTION") % (card.base_block * 100.0), tr("CARD_ANSWER_ENHANCE")]
	else:
		body_label.text = tr(card.description)


func _update_typography() -> void:
	var english: bool = TranslationServer.get_locale().begins_with("en")
	var translated_title: String = title_label.text
	var title_size: int = 12 if english else 15
	if (english and translated_title.length() > 16) or (not english and translated_title.length() > 4):
		title_size -= 2
	title_label.add_theme_font_size_override("font_size", title_size)
	body_label.add_theme_font_size_override("font_size", 10 if english else 13)


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
