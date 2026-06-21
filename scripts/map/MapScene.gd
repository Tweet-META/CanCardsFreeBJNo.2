extends Control
## 地图场景控制器；读取楼层数据、切换楼层图片，并预留关卡节点容器。
class_name MapScene

const PAPER: Color = Color(0.86, 0.78, 0.64, 0.96)
const INK: Color = Color(0.12, 0.10, 0.08)
const STAGE_NODE_SCENE: PackedScene = preload("res://scenes/ui/StageNode.tscn")

@onready var map_texture: TextureRect = $MapTexture
@onready var back_button: Button = $Header/BackButton
@onready var floor_title: Label = $Header/FloorTitle
@onready var floor_selector: OptionButton = $Header/FloorSelector
@onready var stage_layer: Control = $StageLayer

var floors: Array[MapFloorData] = []
var selected_floor_index: int = 0
var stage_nodes: Array[StageNode] = []


func _ready() -> void:
	back_button.pressed.connect(_return_to_menu)
	floor_selector.item_selected.connect(_select_floor)
	stage_layer.resized.connect(_layout_stage_nodes)
	LanguageManager.language_changed.connect(_on_language_changed)
	_apply_styles()
	_load_floor_list()


func _load_floor_list() -> void:
	floors = MapDatabase.get_floors()
	floor_selector.clear()
	for floor: MapFloorData in floors:
		floor_selector.add_item(tr(floor.display_name))
		var item_index: int = floor_selector.item_count - 1
		floor_selector.set_item_disabled(item_index, not floor.unlocked)

	if floors.is_empty():
		floor_title.text = tr("MAP_NO_FLOORS")
		map_texture.texture = null
		floor_selector.disabled = true
		return

	selected_floor_index = clampi(MapDatabase.get_default_floor_index(floors), 0, floors.size() - 1)
	floor_selector.select(selected_floor_index)
	_refresh_floor()


func _select_floor(index: int) -> void:
	if index < 0 or index >= floors.size() or not floors[index].unlocked:
		return
	selected_floor_index = index
	_refresh_floor()


func _refresh_floor() -> void:
	var floor: MapFloorData = floors[selected_floor_index]
	floor_title.text = tr(floor.display_name)
	map_texture.texture = load(floor.image_path) as Texture2D
	_refresh_stage_layer(floor)


func _refresh_stage_layer(floor: MapFloorData) -> void:
	# 楼层只保存关卡 ID；具体位置、入口和解锁状态来自 StageDatabase。
	for child: Node in stage_layer.get_children():
		child.queue_free()
	stage_nodes.clear()

	for stage: StageData in StageDatabase.create_stages(floor.stage_ids):
		if stage.floor_id != floor.id:
			push_error("MapScene: stage '%s' belongs to floor '%s', not '%s'." % [stage.id, stage.floor_id, floor.id])
			continue
		var stage_node: StageNode = STAGE_NODE_SCENE.instantiate() as StageNode
		stage_layer.add_child(stage_node)
		stage_node.setup(stage)
		stage_node.stage_selected.connect(_enter_stage)
		stage_node.size = stage_node.custom_minimum_size
		stage_nodes.append(stage_node)
	call_deferred("_layout_stage_nodes")


func _layout_stage_nodes() -> void:
	if stage_layer == null or stage_layer.size == Vector2.ZERO:
		return
	for stage_node: StageNode in stage_nodes:
		if stage_node.stage_data == null:
			continue
		var center: Vector2 = stage_layer.size * stage_node.stage_data.map_position
		stage_node.position = center - stage_node.size * 0.5


func _on_language_changed(_locale: String) -> void:
	for index in floors.size():
		floor_selector.set_item_text(index, tr(floors[index].display_name))
	for stage_node: StageNode in stage_nodes:
		stage_node.refresh_language()
	if not floors.is_empty():
		floor_title.text = tr(floors[selected_floor_index].display_name)


func _return_to_menu() -> void:
	get_tree().change_scene_to_file("res://scenes/MainMenu.tscn")


func _enter_stage(stage: StageData) -> void:
	StageDatabase.set_active_stage(stage.id)
	get_tree().change_scene_to_file(stage.scene_path)


func _apply_styles() -> void:
	back_button.add_theme_stylebox_override("normal", _style(PAPER, 12, 3))
	back_button.add_theme_stylebox_override("hover", _style(Color(0.94, 0.87, 0.72), 12, 3))
	back_button.add_theme_color_override("font_color", INK)
	floor_selector.add_theme_stylebox_override("normal", _style(PAPER, 12, 3))
	floor_selector.add_theme_color_override("font_color", INK)
	floor_title.add_theme_color_override("font_color", Color(0.96, 0.91, 0.80))
	floor_title.add_theme_color_override("font_outline_color", Color(0.08, 0.06, 0.04))
	floor_title.add_theme_constant_override("outline_size", 6)


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
