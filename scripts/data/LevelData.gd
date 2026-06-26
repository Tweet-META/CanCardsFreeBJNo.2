extends Resource
## 地图关卡的静态配置；坐标为 LevelLayer 内的归一化位置。
class_name LevelData

@export var id: String = ""
@export var display_name: String = ""
@export var marker_text: String = ""
@export var map_id: String = ""
@export var map_position: Vector2 = Vector2(0.5, 0.5)
@export var scene_path: String = ""
@export var battle_background: String = ""
@export var waves: Array[LevelWaveData] = []
@export var unlocked: bool = false
