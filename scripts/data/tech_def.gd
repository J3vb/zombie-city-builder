class_name TechDef
extends Resource
## A blueprint unlock, its prerequisite and the supplies it consumes once.

@export var id: StringName
@export var title: String
@export var benefit: String
@export var requires: StringName
@export var cost: Dictionary[StringName, int] = {}
