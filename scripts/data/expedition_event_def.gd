class_name ExpeditionEventDef
extends Resource
## A discovery and the consequences of staying to investigate.

@export_multiline var story: String
@export var investigate: String
@export var leave: String = "Take the supplies and leave"
@export var extra: Dictionary[StringName, int] = {}
@export var survivor := false
@export var followers := 0
@export var injury := 0
@export var extra_hours := 1.0
