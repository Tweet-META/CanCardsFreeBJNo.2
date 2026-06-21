extends Resource
## 地图关卡的静态配置；坐标为 StageLayer 内的归一化位置。
class_name StageData

@export var id: String = ""
@export var display_name: String = ""
@export var description: String = ""
@export var marker_text: String = ""
@export var floor_id: String = ""
@export var map_position: Vector2 = Vector2(0.5, 0.5)
@export var scene_path: String = ""
@export var battle_background: String = ""
@export var waves: Array[StageWaveData] = []
@export var unlocked: bool = false
