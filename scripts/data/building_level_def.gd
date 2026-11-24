class_name BuildingLevelDef
extends Resource
## Cost, health and appearance of a building at one growth stage.

@export var title: String
@export var min_day: int = 1
@export var cost: Dictionary[StringName, int] = {}
@export var storage_capacity: int = 0
@export var max_health: int = 100
@export var height: float = 3.0
@export var color: Color = Color.WHITE
@export_file("*.tscn") var model_path: String
