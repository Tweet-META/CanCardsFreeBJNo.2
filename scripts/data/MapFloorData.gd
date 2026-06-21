extends Resource
## 单层地图的静态配置；关卡 ID 将在关卡系统接入后由地图界面解析。
class_name MapFloorData

@export var id: String = ""
@export var display_name: String = ""
@export var image_path: String = ""
@export var unlocked: bool = false
@export var stage_ids: Array[String] = []
