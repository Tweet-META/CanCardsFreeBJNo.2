extends Resource
## 单个敌方技能的静态配置；权重用于同一敌人的技能随机选择。
class_name EnemyAbilityData

@export var id: String = ""
@export var power: int = 0
@export var weight: float = 1.0

