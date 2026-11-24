class_name TownGrower
extends Node
## Grows homes on connected parcels and production buildings in painted zones.

signal zones_changed

enum Result { SKIP, WAIT, DONE }

var zones: Dictionary[Vector2i, BuildingDef] = {}
var paused := false
var status := ""
var world: World
var rules: BalanceDef
var _farm: BuildingDef
var _storage: BuildingDef
var _turn := 0
var _hours := 0.0
var _grown := 0
var _upgraded := 0
var _nearby := PackedInt32Array()


func setup(owner_world: World) -> void:
	world = owner_world
	rules = world.plots.rules
	_farm = load("res://data/buildings/farm.tres")
	_storage = load("res://data/buildings/storage.tres")
	GameClock.sim_tick.connect(_tick)
	EventBus.day_started.connect(_dawn)


func _exit_tree() -> void:
	if GameClock.sim_tick.is_connected(_tick):
		GameClock.sim_tick.disconnect(_tick)
	if EventBus.day_started.is_connected(_dawn):
		EventBus.day_started.disconnect(_dawn)


func paint(rect: Rect2i, zone: BuildingDef) -> void:
	if zone != null and zone != _farm and zone != _storage:
		return
	var area := rect.intersection(Rect2i(Vector2i.ZERO, world.grid.size))
	for y in range(area.position.y, area.end.y):
		for x in range(area.position.x, area.end.x):
			var cell := Vector2i(x, y)
			if zone == null:
				zones.erase(cell)
			elif (
				world.grid.base_cost[world.grid.index(cell)] > 0
				and not world.grid.road_cells.has(cell)
				and not world.grid.parcel_cells.has(cell)
			):
				zones[cell] = zone
	zones_changed.emit()


func _dawn(_day: int) -> void:
	_grown = 0
	_upgraded = 0
	for id: StringName in rules.daily_income:
		Economy.add(id, rules.daily_income[id])


func _tick(dt: float) -> void:
	if paused or GameClock.is_night():
		_hours = 0.0
		return
	_hours += dt * 24.0 / rules.day_length_seconds
	while _hours >= rules.growth_hours:
		_hours -= rules.growth_hours
		step()


func step() -> void:
	if (
		paused
		or GameClock.is_night()
		or not is_instance_valid(world.command_post)
		or world.command_post.is_queued_for_deletion()
	):
		return
	for attempt in 4:
		var result := Result.SKIP
		match _turn:
			0:
				result = _upgrade_building()
			1:
				result = _grow_home()
			2:
				result = _grow_zone(_farm)
			3:
				result = _grow_zone(_storage)
		if result == Result.WAIT:
			return
		_turn = (_turn + 1) % 4
		if result == Result.DONE:
			return
	status = "Waiting for an eligible plot, zone or upgrade."


func _nearest_vacant_plot() -> FrontagePlot:
	var best: FrontagePlot
	var distance := INF
	for plot: FrontagePlot in world.plots.plots.values():
		if not world.plots.connected(plot):
			continue
		if (
			is_instance_valid(plot.home)
			or not world.can_build_on(world.plots.house_def, plot.house_cells[0], plot)
			or not _clear(plot.center)
		):
			continue
		var d := plot.center.distance_squared_to(world.command_post.sim_center())
		if d < distance or (is_equal_approx(d, distance) and plot.id < best.id):
			best = plot
			distance = d
	return best


func _clear(center: Vector2) -> bool:
	return (
		world.zombies.query(center, world.grid.tile_size * rules.growth_clearance_tiles, _nearby)
		== 0
	)


func _grow_home() -> Result:
	if _grown >= rules.growth_per_day:
		return Result.SKIP
	var plot := _nearest_vacant_plot()
	if plot == null:
		return Result.SKIP
	var def := world.plots.house_def
	if not Economy.can_afford(def.cost):
		status = "Saving for a tent."
		return Result.WAIT
	if world.try_place_building(def, plot.house_cells[0], plot) == null:
		return Result.SKIP
	_grown += 1
	status = "A tent grew on a street plot."
	return Result.DONE


func _has_upgrade_site(building: Building) -> bool:
	return (
		building.def != world.plots.house_def
		or (building.plot != null and world.plots.connected(building.plot))
	)


func upgrade_status(building: Building) -> String:
	var blocker := building.upgrade_blocker()
	if not blocker.is_empty():
		return blocker
	if not _has_upgrade_site(building):
		return "Needs a connected home plot"
	if paused:
		return "Town growth is paused"
	if GameClock.speed == 0:
		return "Clock is paused"
	if _upgraded >= rules.upgrades_per_day:
		return "Daily limit reached"
	return "Waiting for its turn"


func _upgrade_building() -> Result:
	if _upgraded >= rules.upgrades_per_day:
		return Result.SKIP
	var best: Building
	var best_affordable := false
	var best_index := -1
	var distance := INF
	var origin := world.command_post.sim_center()
	for building: Building in world.buildings.get_children():
		var next := building.next_level()
		if building.is_queued_for_deletion() or next == null or GameClock.day < next.min_day:
			continue
		if not _has_upgrade_site(building):
			continue
		var affordable := Economy.can_afford(next.cost)
		if best_affordable and not affordable:
			continue
		var d := origin.distance_squared_to(building.sim_center())
		var index := world.grid.index(building.cell)
		var farther := d > distance or (d == distance and index >= best_index)
		if affordable == best_affordable and farther:
			continue
		best = building
		distance = d
		best_index = index
		best_affordable = affordable
	if best == null:
		return Result.SKIP
	var next := best.next_level()
	if not best_affordable:
		status = "Saving for %s." % next.title
		return Result.WAIT
	if not best.upgrade():
		return Result.SKIP
	_upgraded += 1
	status = "%s upgraded to %s." % [best.def.display_name, next.title]
	return Result.DONE


func _grow_zone(def: BuildingDef) -> Result:
	if _grown >= rules.growth_per_day:
		return Result.SKIP
	var best := Vector2i(-1, -1)
	var distance := INF
	for cell: Vector2i in zones:
		if zones[cell] != def:
			continue
		var center := world.grid.cell_to_world(cell)
		var d := center.distance_squared_to(world.command_post.sim_center())
		if d > distance or (d == distance and world.grid.index(cell) >= world.grid.index(best)):
			continue
		if not _wholly_zoned(cell, def) or not world.can_build_on(def, cell) or not _clear(center):
			continue
		best = cell
		distance = d
	if best.x < 0:
		return Result.SKIP
	if not Economy.can_afford(def.cost):
		status = "Saving for %s." % def.display_name
		return Result.WAIT
	if world.try_place_building(def, best) == null:
		return Result.SKIP
	_grown += 1
	status = "%s grew in its zone." % def.display_name
	return Result.DONE


func _wholly_zoned(anchor: Vector2i, def: BuildingDef) -> bool:
	for cell in Grid.cells_of(anchor, def.size):
		if zones.get(cell) != def:
			return false
	return true
