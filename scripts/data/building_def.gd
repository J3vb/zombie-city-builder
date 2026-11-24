class_name BuildingDef
extends Resource
## One building type. Edit the .tres files in data/buildings/.

@export var id: StringName
@export var display_name: String
@export var size: Vector2i = Vector2i(1, 1)
@export var cost: Dictionary[StringName, int] = {}
@export var max_health: int = 100
@export var is_goal: bool = true
@export var scene: PackedScene
@export var levels: Array[BuildingLevelDef] = []
@export var view_height: float = 3.0
@export var color: Color = Color(0.6, 0.6, 0.6)


func cost_text() -> String:
	if cost.is_empty():
		return "free"
	var parts: PackedStringArray = []
	for id_key: StringName in cost:
		parts.append("%d %s" % [cost[id_key], id_key])
	return ", ".join(parts)
