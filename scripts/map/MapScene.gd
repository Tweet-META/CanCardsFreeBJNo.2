extends Control
## 地图场景控制器；读取地图数据、切换地图图片，并生成关卡节点。
class_name MapScene

const PAPER: Color = Color(0.86, 0.78, 0.64, 0.96)
const INK: Color = Color(0.12, 0.10, 0.08)
const LEVEL_NODE_SCENE: PackedScene = preload("res://scenes/ui/LevelNode.tscn")

@onready var map_texture: TextureRect = $MapTexture
@onready var back_button: Button = $Header/BackButton
@onready var map_title: Label = $Header/MapTitle
@onready var map_selector: OptionButton = $Header/MapSelector
@onready var level_layer: Control = $LevelLayer

var maps: Array[MapData] = []
var selected_map_index: int = 0
var level_nodes: Array[LevelNode] = []


## 初始化地图界面信号、样式和首张地图。
func _ready() -> void:
	back_button.pressed.connect(_return_to_menu)
	map_selector.item_selected.connect(_select_map)
	level_layer.resized.connect(_layout_level_nodes)
	LanguageManager.language_changed.connect(_on_language_changed)
	_apply_styles()
	_load_map_list()


## 从地图数据库读取可选地图，并显示默认地图。
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


## 用户切换地图下拉框时刷新地图内容。
func _select_map(index: int) -> void:
	if index < 0 or index >= maps.size() or not maps[index].unlocked:
		return
	selected_map_index = index
	_refresh_map()


## 刷新当前地图的标题、底图和关卡节点。
func _refresh_map() -> void:
	var map_data: MapData = maps[selected_map_index]
	map_title.text = tr(map_data.display_name)
	map_texture.texture = load(map_data.image_path) as Texture2D
	_refresh_level_layer(map_data)


## 根据地图记录的关卡 ID 创建本地图上的关卡入口。
func _refresh_level_layer(map_data: MapData) -> void:
	# 地图只保存关卡 ID；具体位置、入口和解锁状态来自 LevelDatabase。
	for child: Node in level_layer.get_children():
		child.queue_free()
	level_nodes.clear()

	for level: LevelData in LevelDatabase.create_levels(map_data.level_ids):
		if level.map_id != map_data.id:
			push_error("MapScene: level '%s' belongs to map '%s', not '%s'." % [level.id, level.map_id, map_data.id])
			continue
		var level_node: LevelNode = LEVEL_NODE_SCENE.instantiate() as LevelNode
		level_layer.add_child(level_node)
		level_node.setup(level)
		level_node.level_selected.connect(_enter_level)
		level_node.size = level_node.custom_minimum_size
		level_nodes.append(level_node)
	call_deferred("_layout_level_nodes")


## 按归一化坐标把关卡入口摆放到地图图片区域。
func _layout_level_nodes() -> void:
	if level_layer == null or level_layer.size == Vector2.ZERO:
		return
	for level_node: LevelNode in level_nodes:
		if level_node.level_data == null:
			continue
		var center: Vector2 = level_layer.size * level_node.level_data.map_position
		level_node.position = center - level_node.size * 0.5


## 语言切换时刷新地图和关卡的显示文本。
func _on_language_changed(_locale: String) -> void:
	for index in maps.size():
		map_selector.set_item_text(index, tr(maps[index].display_name))
	for level_node: LevelNode in level_nodes:
		level_node.refresh_language()
	if not maps.is_empty():
		map_title.text = tr(maps[selected_map_index].display_name)


## 返回主菜单。
func _return_to_menu() -> void:
	get_tree().change_scene_to_file("res://scenes/MainMenu.tscn")


## 记录当前关卡并切换到其目标场景。
func _enter_level(level: LevelData) -> void:
	LevelDatabase.set_active_level(level.id)
	get_tree().change_scene_to_file(level.scene_path)


## 应用地图界面的纸张风格。
func _apply_styles() -> void:
	back_button.add_theme_stylebox_override("normal", _style(PAPER, 12, 3))
	back_button.add_theme_stylebox_override("hover", _style(Color(0.94, 0.87, 0.72), 12, 3))
	back_button.add_theme_color_override("font_color", INK)
	map_selector.add_theme_stylebox_override("normal", _style(PAPER, 12, 3))
	map_selector.add_theme_color_override("font_color", INK)
	map_title.add_theme_color_override("font_color", Color(0.96, 0.91, 0.80))
	map_title.add_theme_color_override("font_outline_color", Color(0.08, 0.06, 0.04))
	map_title.add_theme_constant_override("outline_size", 6)


## 创建地图按钮和下拉框共用的样式盒。
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
