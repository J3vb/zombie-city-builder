class_name PlotMap
extends Node
## Validates road frontage and holds each parcel until the player releases it.

signal changed

var plots: Dictionary[int, FrontagePlot] = {}
var grid: Grid
var roads: RoadNetwork
var rules: BalanceDef
var house_def: BuildingDef
var _next_id := 1


func setup(owner_world: World) -> void:
	grid = owner_world.grid
	roads = owner_world.roads
	rules = load("res://data/balance.tres")
	house_def = load("res://data/buildings/house.tres")
	roads.removal_guard = _road_removal_error
	roads.changed.connect(_on_roads_changed)
	EventBus.building_destroyed.connect(_on_building_destroyed)


func preview(cursor: Vector2, frontage: float) -> FrontagePlot:
	var plot := FrontagePlot.new()
	var hit := roads.nearest(cursor, rules.plot_pick_distance)
	if hit.is_empty():
		plot.error = "Choose a side of a street."
		return plot
	var house_size := Vector2(house_def.size) * grid.tile_size
	var depth := house_size.y + rules.plot_setback
	if frontage < house_size.x or frontage > rules.plot_max_size:
		plot.error = "Choose frontage wide enough for the house."
		return plot
	var side: Vector2 = hit.tangent
	var back := side.orthogonal()
	plot.attachment = hit.point
	if (cursor - plot.attachment).dot(back) < 0:
		back = -back
	plot.front = -back
	plot.road_id = hit.road.id
	var verge := plot.attachment + back * (roads.width * 0.5 + rules.plot_verge)
	var doorstep := verge + back * rules.plot_setback
	plot.center = doorstep + back * house_size.y * 0.5
	plot.polygon = FrontagePlot.rectangle(verge, side, back, frontage, depth)
	plot.house = FrontagePlot.rectangle(doorstep, side, back, house_size.x, house_size.y)
	plot.cells = GroundShape.cells_of(plot.polygon, grid.tile_size)
	plot.path_to_street = FrontagePlot.rectangle(
		doorstep, side, plot.front, grid.tile_size * 0.28, rules.plot_setback + rules.plot_verge
	)
	for cell in GroundShape.cells_of(plot.path_to_street, grid.tile_size):
		if not plot.cells.has(cell):
			plot.cells.append(cell)
	plot.house_cells = GroundShape.cells_of(plot.house, grid.tile_size)
	plot.door = grid.world_to_cell(doorstep + plot.front * rules.plot_setback)
	var street: Street = hit.road
	var remaining_front := street.line[hit.segment].distance_to(hit.point)
	for i in int(hit.segment):
		remaining_front += street.line[i].distance_to(street.line[i + 1])
	var remaining_back := street.line[hit.segment + 1].distance_to(hit.point)
	for i in range(int(hit.segment) + 1, street.line.size() - 1):
		remaining_back += street.line[i].distance_to(street.line[i + 1])
	if minf(remaining_front, remaining_back) < frontage * 0.5:
		plot.error = "Move along the road so the full frontage fits."
	else:
		plot.error = _geometry_error(plot, street)
	return plot


func _geometry_error(plot: FrontagePlot, road: Street) -> String:
	if not roads.reachable.has(road.line[0]):
		return "Connect this street to Station 4 first."
	for cell in plot.cells:
		if grid.get_cost(cell) <= 0 or grid.parcel_cells.has(cell) or grid.barriers.has(cell):
			return "The plot overlaps blocked or reserved land."
	if (
		not grid.is_free(plot.house_cells)
		or plot.house_cells.has(plot.door)
		or grid.get_cost(plot.door) <= 0
	):
		return "Leave a clear entrance and space for the house."
	for existing: Street in roads.roads.values():
		for strip in existing.strips:
			if not Geometry2D.intersect_polygons(strip, plot.polygon).is_empty():
				return "The plot extends into a street."
	return ""


func reserve(cursor: Vector2, frontage: float) -> FrontagePlot:
	var plot := preview(cursor, frontage)
	if not plot.error.is_empty():
		return null
	plot.id = _next_id
	_next_id += 1
	plots[plot.id] = plot
	for cell in plot.cells:
		grid.parcel_cells[cell] = plot.id
		grid.cell_edited.emit(cell)
	changed.emit()
	return plot


func plot_at(point: Vector2) -> FrontagePlot:
	for plot: FrontagePlot in plots.values():
		if Geometry2D.is_point_in_polygon(point, plot.polygon):
			return plot
	return null


func remove_plot(id: int) -> bool:
	if not plots.has(id) or is_instance_valid(plots[id].home):
		return false
	var plot := plots[id]
	for cell in plot.cells:
		if grid.parcel_cells.get(cell, 0) == id:
			grid.parcel_cells.erase(cell)
			grid.cell_edited.emit(cell)
	plots.erase(id)
	changed.emit()
	return true


func connected(plot: FrontagePlot) -> bool:
	return roads.roads.has(plot.road_id) and roads.reachable.has(roads.roads[plot.road_id].line[0])


func _road_removal_error(id: int) -> String:
	var remaining := roads.reachable_without(id)
	for plot: FrontagePlot in plots.values():
		if not is_instance_valid(plot.home):
			continue
		if (
			plot.road_id == id
			or (connected(plot) and not remaining.has(roads.roads[plot.road_id].line[0]))
		):
			return "This road serves an occupied home. Demolish the home first."
	return ""


func _on_roads_changed() -> void:
	for id: int in plots.keys():
		if not roads.roads.has(plots[id].road_id):
			remove_plot(id)


func _on_building_destroyed(building: Node) -> void:
	if (
		building is Building
		and building.plot != null
		and plots.get(building.plot.id) == building.plot
	):
		building.plot.home = null
		changed.emit()
