class_name MapDef
extends Resource
## Layout of a generated map. tile_size must match the terrain TileSet.

@export var size: Vector2i = Vector2i(128, 128)
@export var tile_size: int = 32
@export var border_width: int = 1
@export var water_rects: Array[Rect2i] = []
@export var rubble_rects: Array[Rect2i] = []
@export var command_post_cell: Vector2i = Vector2i(63, 63)
