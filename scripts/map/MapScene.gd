extends Control
## Defines the MapScene script.
class_name MapScene

const PAPER: Color = Color(0.86, 0.78, 0.64, 0.96)
const INK: Color = Color(0.12, 0.10, 0.08)
const LEVEL_NODE_SCENE: PackedScene = preload("res://scenes/ui/LevelNode.tscn")
const PREP_PANEL_HEIGHT: float = 345.0

@onready var map_texture: TextureRect = $MapTexture
@onready var back_button: Button = $Header/BackButton
@onready var map_title: Label = $Header/MapTitle
@onready var map_selector: OptionButton = $Header/MapSelector
@onready var level_layer: Control = $LevelLayer
@onready var prep_overlay: Control = $PrepOverlay
@onready var prep_dimmer: ColorRect = $PrepOverlay/Dimmer
@onready var prep_panel: PanelContainer = $PrepOverlay/PrepPanel
@onready var prep_level_title: Label = $PrepOverlay/PrepPanel/PrepContent/Header/LevelTitle
@onready var prep_wave_label: Label = $PrepOverlay/PrepPanel/PrepContent/Header/WaveLabel
@onready var prep_description_label: Label = $PrepOverlay/PrepPanel/PrepContent/Header/DescriptionLabel
@onready var slot_top_button: Button = $PrepOverlay/PrepPanel/PrepContent/SlotRow/SlotTop
@onready var slot_middle_button: Button = $PrepOverlay/PrepPanel/PrepContent/SlotRow/SlotMiddle
@onready var slot_bottom_button: Button = $PrepOverlay/PrepPanel/PrepContent/SlotRow/SlotBottom
@onready var character_list: HBoxContainer = $PrepOverlay/PrepPanel/PrepContent/CharacterList
@onready var prep_back_button: Button = $PrepOverlay/PrepPanel/PrepContent/Footer/PrepBackButton
@onready var prep_start_button: Button = $PrepOverlay/PrepPanel/PrepContent/Footer/PrepStartButton

var maps: Array[MapData] = []
var selected_map_index: int = 0
var level_nodes: Array[LevelNode] = []
var available_characters: Array[CharacterData] = []
var selected_character_ids: Array[String] = []
var pending_level: LevelData
var prep_tween: Tween


## Ready.
func _ready() -> void:
	back_button.pressed.connect(_return_to_menu)
	map_selector.item_selected.connect(_select_map)
	level_layer.resized.connect(_layout_level_nodes)
	LanguageManager.language_changed.connect(_on_language_changed)
	slot_top_button.pressed.connect(_remove_selected_slot.bind(0))
	slot_middle_button.pressed.connect(_remove_selected_slot.bind(1))
	slot_bottom_button.pressed.connect(_remove_selected_slot.bind(2))
	prep_dimmer.gui_input.connect(_on_preparation_dimmer_input)
	prep_back_button.pressed.connect(_close_preparation)
	prep_start_button.pressed.connect(_confirm_enter_level)
	_set_preparation_panel_open(false, false)
	_apply_styles()
	_load_map_list()


## Load map list.
func _load_map_list() -> void:
	maps = MapDatabase.get_maps()
	map_selector.clear()
	for map_data: MapData in maps:
		map_selector.add_item(tr(map_data.display_name))
		var item_index: int = map_selector.item_count - 1
		map_selector.set_item_disabled(item_index, not map_data.unlocked)

	if maps.is_empty():
		map_title.text = tr("MAP_NO_MAPS")
		map_texture.texture = null
		map_selector.disabled = true
		return

	selected_map_index = clampi(MapDatabase.get_default_map_index(maps), 0, maps.size() - 1)
	map_selector.select(selected_map_index)
	_refresh_map()


## Select map.
func _select_map(index: int) -> void:
	if index < 0 or index >= maps.size() or not maps[index].unlocked:
		return
	selected_map_index = index
	_refresh_map()


## Refresh map.
func _refresh_map() -> void:
	var map_data: MapData = maps[selected_map_index]
	map_title.text = tr(map_data.display_name)
	map_texture.texture = load(map_data.image_path) as Texture2D
	_refresh_level_layer(map_data)


## Refresh level layer.
func _refresh_level_layer(map_data: MapData) -> void:
	for child: Node in level_layer.get_children():
		child.queue_free()
	level_nodes.clear()

	for level: LevelData in LevelDatabase.create_levels(map_data.level_ids):
		if level.map_id != map_data.id:
			push_error("MapScene: level '%s' belongs to map '%s', not '%s'." % [level.id, level.map_id, map_data.id])
			continue
		level.unlocked = SaveManager.is_level_unlocked(level.id)
		var level_node: LevelNode = LEVEL_NODE_SCENE.instantiate() as LevelNode
		level_layer.add_child(level_node)
		level_node.setup(level)
		level_node.level_selected.connect(_enter_level)
		level_node.size = level_node.custom_minimum_size
		level_nodes.append(level_node)
	call_deferred("_layout_level_nodes")


## Layout level nodes.
func _layout_level_nodes() -> void:
	if level_layer == null or level_layer.size == Vector2.ZERO:
		return
	for level_node: LevelNode in level_nodes:
		if level_node.level_data == null:
			continue
		var center: Vector2 = level_layer.size * level_node.level_data.map_position
		level_node.position = center - level_node.size * 0.5


## On language changed.
func _on_language_changed(_locale: String) -> void:
	for index in maps.size():
		map_selector.set_item_text(index, tr(maps[index].display_name))
	for level_node: LevelNode in level_nodes:
		level_node.refresh_language()
	if not maps.is_empty():
		map_title.text = tr(maps[selected_map_index].display_name)
	if pending_level != null:
		_refresh_preparation_text()
		_refresh_preparation_slots()
		_refresh_character_buttons()


## Return to menu.
func _return_to_menu() -> void:
	get_tree().change_scene_to_file("res://scenes/MainMenu.tscn")


## Enter level.
func _enter_level(level: LevelData) -> void:
	pending_level = level
	available_characters = _create_unlocked_characters()
	selected_character_ids.clear()
	_refresh_preparation_text()
	_refresh_character_buttons()
	_refresh_preparation_slots()
	_set_preparation_panel_open(true, true)


## Creates the character list allowed by the active save.
func _create_unlocked_characters() -> Array[CharacterData]:
	var unlocked_characters: Array[CharacterData] = []
	for character: CharacterData in CharacterDatabase.create_available_characters():
		if SaveManager.is_character_unlocked(character.id):
			unlocked_characters.append(character)
	return unlocked_characters


## Refresh preparation text.
func _refresh_preparation_text() -> void:
	if pending_level == null:
		return
	prep_level_title.text = tr("PREP_LEVEL_FORMAT") % pending_level.marker_text
	prep_wave_label.text = tr("PREP_WAVE_COUNT") % pending_level.waves.size()
	prep_description_label.text = tr(pending_level.description)


## Refresh character buttons.
func _refresh_character_buttons() -> void:
	for child: Node in character_list.get_children():
		child.queue_free()

	for character: CharacterData in available_characters:
		var character_id: String = character.id
		var button: Button = Button.new()
		button.custom_minimum_size = Vector2(155, 54)
		button.toggle_mode = true
		button.button_pressed = character_id in selected_character_ids
		button.text = tr(character.display_name)
		button.disabled = selected_character_ids.size() >= 3 and not (character_id in selected_character_ids)
		button.add_theme_stylebox_override("normal", _style(PAPER, 10, 2))
		button.add_theme_stylebox_override("hover", _style(Color(0.94, 0.87, 0.72), 10, 2))
		button.add_theme_stylebox_override("pressed", _style(Color(0.78, 0.65, 0.42), 10, 2))
		button.add_theme_color_override("font_color", INK)
		button.pressed.connect(_toggle_character.bind(character_id))
		character_list.add_child(button)


## Toggle character.
func _toggle_character(character_id: String) -> void:
	if character_id in selected_character_ids:
		selected_character_ids.erase(character_id)
	elif selected_character_ids.size() < 3:
		selected_character_ids.append(character_id)
	_refresh_character_buttons()
	_refresh_preparation_slots()


## Refresh preparation slots.
func _refresh_preparation_slots() -> void:
	var slot_buttons: Array[Button] = [slot_top_button, slot_middle_button, slot_bottom_button]
	for slot_index in range(slot_buttons.size()):
		var button: Button = slot_buttons[slot_index]
		var selected_index: int = _selected_index_for_slot(slot_index)
		var should_show_empty_middle: bool = selected_character_ids.is_empty() and slot_index == 1
		button.visible = selected_index != -1 or should_show_empty_middle
		button.disabled = selected_index == -1
		button.text = tr("PREP_EMPTY_SLOT") if selected_index == -1 else _character_name_for_id(selected_character_ids[selected_index])
		button.add_theme_stylebox_override("normal", _style(Color(0.90, 0.82, 0.68, 0.96), 14, 3))
		button.add_theme_stylebox_override("hover", _style(Color(0.98, 0.88, 0.62, 0.98), 14, 3))
	prep_start_button.disabled = selected_character_ids.is_empty()


## Selected index for slot.
func _selected_index_for_slot(slot_index: int) -> int:
	match selected_character_ids.size():
		0:
			return -1
		1:
			return 0 if slot_index == 0 else -1
		2:
			if slot_index == 0:
				return 0
			if slot_index == 2:
				return 1
			return -1
		_:
			return slot_index if slot_index < selected_character_ids.size() else -1


## Remove selected slot.
func _remove_selected_slot(slot_index: int) -> void:
	var selected_index: int = _selected_index_for_slot(slot_index)
	if selected_index < 0 or selected_index >= selected_character_ids.size():
		return
	selected_character_ids.remove_at(selected_index)
	_refresh_character_buttons()
	_refresh_preparation_slots()


## Character name for id.
func _character_name_for_id(character_id: String) -> String:
	for character: CharacterData in available_characters:
		if character.id == character_id:
			return tr(character.display_name)
	return character_id


## Close preparation.
func _close_preparation() -> void:
	_set_preparation_panel_open(false, true)


## On preparation dimmer input.
func _on_preparation_dimmer_input(event: InputEvent) -> void:
	var mouse_event: InputEventMouseButton = event as InputEventMouseButton
	if mouse_event == null:
		return
	if mouse_event.button_index == MOUSE_BUTTON_LEFT and mouse_event.pressed:
		_close_preparation()
		accept_event()


## Confirm enter level.
func _confirm_enter_level() -> void:
	if pending_level == null or selected_character_ids.is_empty():
		return
	LevelDatabase.set_active_level(pending_level.id)
	LevelDatabase.set_active_player_ids(selected_character_ids)
	get_tree().change_scene_to_file(pending_level.scene_path)


## Set preparation panel open.
func _set_preparation_panel_open(open: bool, animated: bool) -> void:
	if prep_tween != null:
		prep_tween.kill()
	var was_visible: bool = prep_overlay.visible
	prep_overlay.visible = true
	prep_overlay.mouse_filter = Control.MOUSE_FILTER_STOP if open else Control.MOUSE_FILTER_IGNORE

	var target_top: float = -PREP_PANEL_HEIGHT if open else 0.0
	var target_bottom: float = 0.0 if open else PREP_PANEL_HEIGHT
	if not animated:
		prep_panel.offset_top = target_top
		prep_panel.offset_bottom = target_bottom
		prep_overlay.visible = open
		return

	if open and not was_visible:
		prep_panel.offset_top = 0.0
		prep_panel.offset_bottom = PREP_PANEL_HEIGHT
	prep_tween = create_tween()
	prep_tween.set_ease(Tween.EASE_OUT)
	prep_tween.set_trans(Tween.TRANS_CUBIC)
	prep_tween.tween_property(prep_panel, "offset_top", target_top, 0.22)
	prep_tween.parallel().tween_property(prep_panel, "offset_bottom", target_bottom, 0.22)
	if not open:
		prep_tween.finished.connect(func() -> void: prep_overlay.visible = false)


## Apply styles.
func _apply_styles() -> void:
	back_button.add_theme_stylebox_override("normal", _style(PAPER, 12, 3))
	back_button.add_theme_stylebox_override("hover", _style(Color(0.94, 0.87, 0.72), 12, 3))
	back_button.add_theme_color_override("font_color", INK)
	map_selector.add_theme_stylebox_override("normal", _style(PAPER, 12, 3))
	map_selector.add_theme_color_override("font_color", INK)
	map_title.add_theme_color_override("font_color", Color(0.96, 0.91, 0.80))
	map_title.add_theme_color_override("font_outline_color", Color(0.08, 0.06, 0.04))
	map_title.add_theme_constant_override("outline_size", 6)
	prep_panel.add_theme_stylebox_override("panel", _style(Color(0.86, 0.78, 0.64, 0.98), 18, 4))
	prep_back_button.add_theme_stylebox_override("normal", _style(PAPER, 12, 3))
	prep_start_button.add_theme_stylebox_override("normal", _style(Color(0.91, 0.74, 0.35, 1.0), 12, 3))
	prep_back_button.add_theme_color_override("font_color", INK)
	prep_start_button.add_theme_color_override("font_color", INK)


## Style.
func _style(color: Color, radius: int, border_width: int) -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
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
	style.shadow_color = Color(0, 0, 0, 0.24)
	style.shadow_size = 6
	return style
