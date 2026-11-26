class_name MapDef
extends Resource
## Layout of a generated map. tile_size is measured in simulation units.

@export var display_name := "Halder Ford"
@export_multiline var description := "Open streets around Station 4, between two flooded quarries."
@export var size: Vector2i = Vector2i(128, 128)
@export_range(1, 4096, 1, "or_greater") var tile_size: int = 32
@export_range(0.001, 1.0) var view_scale: float = 0.125
@export var map_seed: int = 1
@export var border_width: int = 1
@export var water_rects: Array[Rect2i] = []
@export var rubble_rects: Array[Rect2i] = []
@export var lakes: Array[Rect2i] = []
@export var highways: Array[PackedVector2Array] = []
@export var places: Array[BasinPlace] = []
@export var overview_distance := 0.0
@export var population_limit := 0
@export var command_post_cell: Vector2i = Vector2i(63, 63)
## Relative to Station 4. Barricades cover the back and sides, leaving the street entrance clear.
@export var starter_yard := Rect2i(-2, -3, 7, 4)
@export var starter_tower := Vector2i(3, 1)
