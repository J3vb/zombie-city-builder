class_name BuildingDef
extends Resource
## One building type. Edit the .tres files in data/buildings/.

enum Placement { DIRECT, HOME_PLOT, ZONE }

@export var output_resource: StringName
@export var shift_yields := PackedInt32Array()
@export var placement := Placement.DIRECT
@export var id: StringName
@export var display_name: String
@export var size: Vector2i = Vector2i(1, 1)
@export var cost: Dictionary[StringName, int] = {}
@export var max_health: int = 100
@export var is_goal: bool = true
@export var scene: PackedScene
@export var model: PackedScene
@export var levels: Array[BuildingLevelDef] = []
@export var view_height: float = 3.0
@export var color: Color = Color(0.6, 0.6, 0.6)


func cost_text() -> String:
	return format_cost(cost)


static func format_cost(amounts: Dictionary[StringName, int]) -> String:
	if amounts.is_empty():
		return "free"
	var parts: PackedStringArray = []
	for id_key: StringName in amounts:
		parts.append("%d %s" % [amounts[id_key], id_key])
	return ", ".join(parts)
