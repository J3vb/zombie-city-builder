class_name ExpeditionSite
extends Resource
## One destination in the Veydam Basin, with travel times and findings.

@export var title: String
@export var district: String
@export var hours := 3.0
@export var search_hours := 2
@export_range(0.0, 1.0) var risk := 0.15
@export var map_position := Vector2.ZERO
@export var supplies: Dictionary[StringName, int] = {}
@export var encounter: ExpeditionEventDef
