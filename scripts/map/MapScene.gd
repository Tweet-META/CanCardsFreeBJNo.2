extends Control
## Defines the MapScene script.
class_name MapScene

@onready var map_texture: TextureRect = $MapTexture
@onready var back_button: Button = $Header/BackButton
@onready var map_title: Label = $Header/MapTitle
@onready var map_selector: OptionButton = $Header/MapSelector
@onready var level_layer: Control = $LevelLayer
@onready var preparation_panel: PreparationPanel = $PreparationPanel
@onready var tutorial_guide: TutorialGuide = $TutorialGuide

var maps: Array[MapData] = []
var selected_map_index: int = 0
var level_nodes: Array[LevelNode] = []
var tutorial: TutorialData
var tutorial_speaker: CharacterData


## Ready.
func _ready() -> void:
	back_button.pressed.connect(_return_to_menu)
	map_selector.item_selected.connect(_select_map)
	LanguageManager.language_changed.connect(_on_language_changed)
	preparation_panel.enter_level_requested.connect(_confirm_enter_level)
	preparation_panel.preparation_changed.connect(_refresh_tutorial_guide)
	var first_level: LevelData = LevelDatabase.create_level(SaveManager.DEFAULT_LEVEL_ID)
	if SaveManager.needs_first_tutorial():
		tutorial = TutorialDatabase.create_for_level(first_level)
		if tutorial != null:
			tutorial_speaker = CharacterDatabase.create_character(tutorial.speaker_id)
	_collect_level_nodes()
	_load_map_list()
	_refresh_tutorial_guide()


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


## Binds the editor-authored level nodes that belong to the selected map.
func _refresh_level_layer(map_data: MapData) -> void:
	for level_node: LevelNode in level_nodes:
		level_node.visible = false
		level_node.level_data = null

	for level_id: String in map_data.level_ids:
		var level_node: LevelNode = _find_level_node(level_id)
		if level_node == null:
			push_error("MapScene: map '%s' has no editor-authored node for level '%s'." % [map_data.id, level_id])
			continue
		var level: LevelData = LevelDatabase.create_level(level_id)
		if level == null:
			continue
		if level.map_id != map_data.id:
			push_error("MapScene: level '%s' belongs to map '%s', not '%s'." % [level.id, level.map_id, map_data.id])
			continue
		level.unlocked = SaveManager.is_level_unlocked(level.id)
		level_node.setup(level)
		level_node.visible = true


## Collects and connects the reusable level nodes placed in the scene editor.
func _collect_level_nodes() -> void:
	level_nodes.clear()
	for child: Node in level_layer.get_children():
		if not child is LevelNode:
			continue
		var level_node: LevelNode = child as LevelNode
		level_nodes.append(level_node)
		level_node.level_selected.connect(_enter_level)


## Returns the editor-authored node assigned to a stable level ID.
func _find_level_node(level_id: String) -> LevelNode:
	for level_node: LevelNode in level_nodes:
		if level_node.level_id == level_id:
			return level_node
	return null


## On language changed.
func _on_language_changed(_locale: String) -> void:
	for index in maps.size():
		map_selector.set_item_text(index, tr(maps[index].display_name))
	for level_node: LevelNode in level_nodes:
		level_node.refresh_language()
	if not maps.is_empty():
		map_title.text = tr(maps[selected_map_index].display_name)


## Return to menu.
func _return_to_menu() -> void:
	get_tree().change_scene_to_file("res://scenes/MainMenu.tscn")


## Enter level.
func _enter_level(level: LevelData) -> void:
	preparation_panel.open_for_level(level, _create_unlocked_characters())


## Creates the character list allowed by the active save.
func _create_unlocked_characters() -> Array[CharacterData]:
	var unlocked_characters: Array[CharacterData] = []
	for character: CharacterData in CharacterDatabase.create_available_characters():
		if SaveManager.is_character_unlocked(character.id):
			unlocked_characters.append(character)
	return unlocked_characters


## Confirms preparation and enters combat through the persistent loading transition.
func _confirm_enter_level(level: LevelData, selected_character_ids: Array[String], learning_goal_character_id: String) -> void:
	if SceneTransition.is_busy() or level == null or selected_character_ids.is_empty():
		return
	if level.requires_learning_goal and learning_goal_character_id.is_empty():
		return
	LevelDatabase.set_active_level(level.id)
	LevelDatabase.set_active_player_ids(selected_character_ids)
	LevelDatabase.set_active_learning_goal_character_id(learning_goal_character_id)
	SceneTransition.enter_level(level)


## Follows actual preparation choices instead of requiring dialogue clicks to advance.
func _refresh_tutorial_guide() -> void:
	if tutorial == null or preparation_panel.learning_goal_drawer.visible:
		tutorial_guide.hide()
		return
	var step: String = "room"
	if preparation_panel.opened:
		if preparation_panel.pending_level == null or preparation_panel.pending_level.id != tutorial.level_id:
			tutorial_guide.hide()
			return
		if preparation_panel.selected_character_ids.is_empty():
			step = "party"
		elif preparation_panel.learning_goal_character_id.is_empty():
			step = "goal"
		else:
			step = "enter"
	tutorial_guide.show_instruction(tutorial_speaker, tutorial.get_map_message(step))
