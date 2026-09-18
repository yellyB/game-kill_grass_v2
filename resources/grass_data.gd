extends Resource
class_name GrassData

@export var grass_name: String = "Normal Grass"
@export var max_health: int = 1
@export var regen_time: float = 5.0
@export var min_drop_value: int = 1
@export var max_drop_value: int = 5
@export var drop_chance: float = 0.2
@export var guaranteed_drop: bool = false
@export var color: Color = Color(0.3, 0.7, 0.3)
@export var cut_color: Color = Color(0.5, 0.4, 0.2)
