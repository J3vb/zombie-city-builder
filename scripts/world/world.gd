class_name World
extends Node2D
## One game's world: terrain, grid, camera and (later) buildings and zombies.

const MAP_PATH := "res://data/maps/starter_map.tres"

var map_def: MapDef

@onready var terrain: TileMapLayer = $Terrain
@onready var grid: Grid = $Grid
@onready var camera: CameraRig = $CameraRig


func _ready() -> void:
	map_def = load(MAP_PATH) as MapDef
	StarterMap.generate(terrain, map_def)
	grid.setup(terrain)
	camera.set_bounds(Rect2(Vector2.ZERO, grid.world_size()))
