class_name World
extends Node2D
## One game's world: terrain, grid, buildings, flow field, zombies, tools.
## Owns the flow field and rebuilds it on a worker thread when the grid changes.

const MAP_PATH := "res://data/maps/starter_map.tres"
const COMMAND_POST := preload("res://data/buildings/command_post.tres")
const NIGHT_COLOR := Color(0.55, 0.6, 0.8)

var map_def: MapDef
var flow_field := FlowField.new()
var command_post: Building
var last_build_ms: float = 0.0

var _dirty := false
var _task_id := -1
var _pending_field: FlowField
var _task_started_usec := 0

@onready var terrain: TileMapLayer = $Terrain
@onready var grid: Grid = $Grid
@onready var buildings: Node2D = $Buildings
@onready var build_tool: BuildTool = $BuildTool
@onready var camera: CameraRig = $CameraRig
@onready var zombies: ZombieManager = $ZombieManager
@onready var horde: HordeDirector = $HordeDirector
@onready var debug_overlay: DebugOverlay = $DebugOverlay
@onready var _night_tint: CanvasModulate = $NightTint


func _ready() -> void:
	map_def = load(MAP_PATH) as MapDef
	StarterMap.generate(terrain, map_def)
	grid.setup(terrain)
	camera.set_bounds(Rect2(Vector2.ZERO, grid.world_size()))
	build_tool.world = self
	command_post = spawn_building(COMMAND_POST, map_def.command_post_cell)
	camera.position = command_post.position + Vector2(COMMAND_POST.size) * tile_size() / 2.0
	grid.changed.connect(_on_grid_changed)
	_build_now()
	zombies.setup(self)
	horde.setup(self, Time.get_ticks_usec())
	debug_overlay.world = self


func _exit_tree() -> void:
	if _task_id != -1:
		WorkerThreadPool.wait_for_task_completion(_task_id)
		_task_id = -1


func tile_size() -> Vector2:
	return Vector2(terrain.tile_set.tile_size)


func spawn_building(def: BuildingDef, cell: Vector2i) -> Building:
	var building := def.scene.instantiate() as Building
	building.setup(def, cell, grid, tile_size())
	buildings.add_child(building)
	grid.occupy(building.cells, building)
	EventBus.building_placed.emit(building)
	return building


func goal_cells() -> PackedInt32Array:
	var goals := PackedInt32Array()
	for cell: Vector2i in grid.occupant:
		var b := grid.occupant[cell] as Building
		if b and b.def.is_goal:
			goals.append(grid.index(cell))
	return goals


func is_rebuilding() -> bool:
	return _task_id != -1


func _on_grid_changed() -> void:
	_dirty = true


func _process(_delta: float) -> void:
	_update_tint()
	if _task_id != -1 and WorkerThreadPool.is_task_completed(_task_id):
		WorkerThreadPool.wait_for_task_completion(_task_id)
		_task_id = -1
		flow_field = _pending_field
		_pending_field = null
		last_build_ms = (Time.get_ticks_usec() - _task_started_usec) / 1000.0
	if _dirty and _task_id == -1:
		_start_build()


func _update_tint() -> void:
	var t := GameClock.time_of_day
	var dark := smoothstep(0.62, 0.72, t) * (1.0 - smoothstep(0.94, 1.0, t))
	_night_tint.color = Color.WHITE.lerp(NIGHT_COLOR, dark)


func _start_build() -> void:
	_dirty = false
	_pending_field = FlowField.new()
	var job := _pending_field.build.bind(grid.cost.duplicate(), grid.size, goal_cells())
	_task_started_usec = Time.get_ticks_usec()
	_task_id = WorkerThreadPool.add_task(job, false, "flow field")


func _build_now() -> void:
	_dirty = false
	var start := Time.get_ticks_usec()
	flow_field.build(grid.cost.duplicate(), grid.size, goal_cells())
	last_build_ms = (Time.get_ticks_usec() - start) / 1000.0
