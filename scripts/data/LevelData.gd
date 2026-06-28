extends Resource
## Defines the LevelData script.
class_name LevelData

@export var id: String = ""
@export var order: int = 1
@export var display_name: String = ""
@export var description: String = ""
@export var marker_text: String = ""
@export var map_id: String = ""
@export var map_position: Vector2 = Vector2(0.5, 0.5)
@export var scene_path: String = ""
@export var battle_background: String = ""
@export var waves: Array[LevelWaveData] = []
@export var unlocked: bool = false
