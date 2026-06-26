extends Resource
## 单张地图的静态配置；关卡 ID 由地图界面解析为 LevelData。
class_name MapData

@export var id: String = ""
@export var display_name: String = ""
@export var image_path: String = ""
@export var unlocked: bool = false
@export var level_ids: Array[String] = []
