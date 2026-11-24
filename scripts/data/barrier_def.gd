class_name BarrierDef
extends Resource
## Cost, strength and breach weight of one perimeter tile.

@export var title: String
@export var cost: Dictionary[StringName, int] = {}
@export var health := 100
@export var break_cost := 20
@export var build_seconds := 3.0
@export var gate := false
@export var height := 1.6
@export var color := Color(0.42, 0.29, 0.16)
