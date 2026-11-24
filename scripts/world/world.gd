class_name World
extends Node3D
## One game's world: terrain, grid, buildings, flow field, zombies, tools.
## Owns the flow field and rebuilds it on a worker thread when the grid changes.

const MAP_PATH := "res://data/maps/starter_map.tres"
const TERRAIN_SET_PATH := "res://data/terrain/terrain_set.tres"
const COMMAND_POST_PATH := "res://data/buildings/command_post.tres"

var map_def: MapDef
var flow_field := FlowField.new()
var safety := TownSafety.new()
var command_post: Building
var last_build_ms: float = 0.0

var _nearby_zombies := PackedInt32Array()
var _dirty := false
var _task_id := -1
var _pending_field: FlowField
var _task_started_usec := 0

@onready var terrain: TerrainMesh = $Terrain
@onready var grid: Grid = $Grid
@onready var buildings: Node3D = $Buildings
@onready var plots: PlotMap = $PlotMap
@onready var construction: ConstructionCrew = $Construction
@onready var jobs: JobBoard = $JobBoard
@onready var grower: TownGrower = $Grower
@onready var plot_tool: PlotTool = $PlotTool
@onready var roads: RoadNetwork = $RoadNetwork
@onready var road_tool: RoadTool = $RoadTool
@onready var build_tool: BuildTool = $BuildTool
@onready var camera: CameraRig = $CameraRig
@onready var zombies: ZombieManager = $ZombieManager
@onready var horde: HordeDirector = $HordeDirector
@onready var debug_overlay: DebugOverlay = $DebugOverlay


func _ready() -> void:
	map_def = load(MAP_PATH) as MapDef
	var terrain_set := load(TERRAIN_SET_PATH) as TerrainSet
	grid.setup(map_def, StarterMap.generate(map_def), terrain_set)
	terrain.build(grid, terrain_set, view_tile(), map_def.map_seed)
	camera.set_bounds(Rect2(Vector2.ZERO, grid.world_size() * map_def.view_scale))
	build_tool.world = self
	command_post = spawn_building(load(COMMAND_POST_PATH) as BuildingDef, map_def.command_post_cell)
	roads.setup(grid, command_post, load("res://data/balance.tres") as BalanceDef)
	road_tool.setup(self)
	plots.setup(self)
	grower.setup(self)
	_refresh_storage()
	EventBus.building_destroyed.connect(_storage_removed)
	jobs.setup(self)
	construction.setup(self)
	plot_tool.setup(self)
	camera.position = to_view(command_post.sim_center())
	grid.changed.connect(_on_grid_changed)
	_build_now()
	zombies.setup(self)
	horde.setup(self, Time.get_ticks_usec())
	debug_overlay.world = self


func _exit_tree() -> void:
	if EventBus.building_destroyed.is_connected(_storage_removed):
		EventBus.building_destroyed.disconnect(_storage_removed)
	if _task_id != -1:
		WorkerThreadPool.wait_for_task_completion(_task_id)
		_task_id = -1


func tile_size() -> Vector2:
	return Vector2.ONE * grid.tile_size


func view_tile() -> float:
	return grid.tile_size * map_def.view_scale


func to_view(point: Vector2) -> Vector3:
	return Vector3(point.x, 0, point.y) * map_def.view_scale


func to_sim(point: Vector3) -> Vector2:
	return Vector2(point.x, point.z) / map_def.view_scale


func can_place_building(def: BuildingDef, cell: Vector2i, site: FrontagePlot = null) -> bool:
	return can_build_on(def, cell, site) and Economy.can_afford(def.cost)


func can_build_on(def: BuildingDef, cell: Vector2i, site: FrontagePlot = null) -> bool:
	var cells := site.house_cells if site != null else Grid.cells_of(cell, def.size)
	if (
		site != null
		and (
			def != plots.house_def
			or plots.plots.get(site.id) != site
			or not plots.connected(site)
			or is_instance_valid(site.home)
		)
	):
		return false
	if not grid.is_free(cells, site.id if site != null else 0) or jobs.blocks_placement(cells):
		return false
	for c in cells:
		if zombies.query(grid.cell_to_world(c), grid.tile_size * 0.71, _nearby_zombies) > 0:
			return false
	return true


## Paid placement, shared by input and simulation callers.
func try_place_building(def: BuildingDef, cell: Vector2i, site: FrontagePlot = null) -> Building:
	if not can_place_building(def, cell, site) or not Economy.spend(def.cost):
		return null
	var building := _place(def, cell, site, true)
	if building == null:
		# A resource listener can claim the cells before the purchase completes.
		Economy.refund(def.cost)
	return building


## Unpaid spawn for map setup. The grid still checks the whole footprint.
func spawn_building(def: BuildingDef, cell: Vector2i, site: FrontagePlot = null) -> Building:
	return _place(def, cell, site, false)


func _place(def: BuildingDef, cell: Vector2i, site: FrontagePlot, paid: bool) -> Building:
	if (
		site != null
		and (
			def != plots.house_def
			or plots.plots.get(site.id) != site
			or not plots.connected(site)
			or is_instance_valid(site.home)
		)
	):
		return null
	var building := def.scene.instantiate() as Building
	building.setup(def, cell, grid, site)
	if jobs.blocks_placement(building.cells) or not grid.occupy(building.cells, building):
		building.free()
		return null
	if paid:
		building.begin_construction(1, def.cost)
	if site != null:
		site.home = building
	buildings.add_child(building)
	building.construction_changed.connect(construction.site_changed.bind(building))
	if not def.levels.is_empty() and def.levels[0].storage_capacity > 0:
		building.construction_changed.connect(_refresh_storage)
		_refresh_storage()
	if paid:
		construction.site_changed(building)
	else:
		EventBus.building_placed.emit(building)
	return building


func _storage_removed(building: Building) -> void:
	if building.get_parent() == buildings and building.storage_capacity() > 0:
		_refresh_storage()


func _refresh_storage() -> void:
	var limit := plots.rules.station_capacity
	for building: Building in buildings.get_children():
		if not building.is_queued_for_deletion():
			limit += building.storage_capacity()
	Economy.set_capacity(limit)


func goal_cells() -> PackedInt32Array:
	var goals := PackedInt32Array()
	for cell: Vector2i in grid.occupant:
		var b := grid.occupant[cell]
		if b and b.def.is_goal:
			goals.append(grid.index(cell))
	return goals


func is_rebuilding() -> bool:
	return _task_id != -1


func _on_grid_changed() -> void:
	_dirty = true


func _process(_delta: float) -> void:
	if _task_id != -1 and WorkerThreadPool.is_task_completed(_task_id):
		WorkerThreadPool.wait_for_task_completion(_task_id)
		_task_id = -1
		flow_field = _pending_field
		_pending_field = null
		last_build_ms = (Time.get_ticks_usec() - _task_started_usec) / 1000.0
	if _dirty and _task_id == -1:
		_start_build()


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
