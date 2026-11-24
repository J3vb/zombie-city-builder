class_name TerrainSet
extends Resource
## Terrain definitions indexed by the IDs stored in the map.

enum Kind { GROUND, RUBBLE, WATER, BORDER }

@export_range(0.0, 1.0) var shade_variation: float = 0.09
@export var types: Array[TerrainDef] = []
