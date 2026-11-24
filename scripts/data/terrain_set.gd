class_name TerrainSet
extends Resource
## Terrain definitions indexed by the IDs stored in the map.

enum Kind { GROUND, RUBBLE, WATER, BORDER }

@export var types: Array[TerrainDef] = []
