class_name RoadNetwork
extends Node
## Owns street geometry and the junction graph. Grid keeps roads open to walkers.

signal changed

var roads: Dictionary[int, Street] = {}
var entrance: Vector2
var width: float
var min_segment: float
var snap_radius: float
var angle_step: float
var angle_tolerance: float
var grid: Grid
var graph: Dictionary[Vector2, PackedVector2Array] = {}
var reachable: Dictionary[Vector2, bool] = {}

var removal_guard: Callable

var _next_id := 1


func setup(owner_grid: Grid, post: Building, balance: BalanceDef) -> void:
	grid = owner_grid
	width = balance.road_width
	min_segment = balance.road_min_length
	snap_radius = balance.road_snap_radius
	angle_step = deg_to_rad(balance.road_angle_step)
	angle_tolerance = deg_to_rad(balance.road_angle_tolerance)
	var bounds := post.sim_bounds()
	entrance = Vector2(bounds.get_center().x, bounds.end.y + width * 0.5)


func nearest(point: Vector2, limit: float) -> Dictionary:
	var hit := {}
	for road: Street in roads.values():
		if not road.bounds.grow(limit + StreetCrossings.EPSILON).has_point(point):
			continue
		var candidate := road.nearest(point)
		if candidate.distance <= limit:
			limit = candidate.distance
			hit = candidate
	return hit


func connection_point(point: Vector2) -> Vector2:
	var best := Vector2.INF
	var limit := snap_radius * snap_radius
	if point.distance_squared_to(entrance) <= limit:
		best = entrance
		limit = point.distance_squared_to(entrance)
	for node: Vector2 in graph:
		var distance := point.distance_squared_to(node)
		if distance < limit or (distance == limit and node < best):
			best = node
			limit = distance
	if best.is_finite():
		return best
	return nearest(point, snap_radius).get("point", Vector2.INF)


func snap_endpoint(point: Vector2) -> Vector2:
	var target := connection_point(point)
	return target if target.is_finite() else point


func preview(points: PackedVector2Array, snap: bool = true, quadratic: bool = false) -> Street:
	var road := Street.new()
	road.controls = points.duplicate()
	road.quadratic = quadratic
	if points.size() < 2 or (quadratic and points.size() != 3):
		road.error = "Click at least two points."
		return road
	if snap:
		road.controls[0] = snap_endpoint(points[0])
		road.controls[-1] = snap_endpoint(points[-1])
	road.error = _control_error(road)
	if not road.error.is_empty():
		return road
	road.bake(width, width / 4.0)
	if road.crosses_itself(width):
		road.error = "The street crosses or doubles back on itself."
		return road
	var covered: Dictionary[Vector2i, bool] = {}
	for strip in road.strips:
		for cell in GroundShape.cells_of(strip, grid.tile_size):
			if grid.get_cost(cell) <= 0 or grid.parcel_cells.has(cell) or grid.barriers.has(cell):
				road.error = "The street crosses blocked land."
				return road
			covered[cell] = true
	road.cells.assign(covered.keys())
	for existing: Street in roads.values():
		if not StreetCrossings.collect(road, existing, width):
			road.error = "Streets overlap. Move farther away or cross at a wider angle."
			break
	return road


func _control_error(road: Street) -> String:
	if road.quadratic and road.controls[0].distance_to(road.controls[-1]) < min_segment:
		return "Move the endpoint farther from the start."
	var minimum := width * 0.15 if road.quadratic else min_segment
	for i in range(1, road.controls.size()):
		if road.controls[i].distance_to(road.controls[i - 1]) < minimum:
			return "Street points are too close."
	for i in range(1, road.controls.size() - 1):
		var incoming := road.controls[i - 1].direction_to(road.controls[i])
		var outgoing := road.controls[i].direction_to(road.controls[i + 1])
		if incoming.dot(outgoing) < -0.94:
			return "The street turns back on itself."
	return ""


func add_road(points: PackedVector2Array, snap: bool = true, quadratic: bool = false) -> Street:
	var road := preview(points, snap, quadratic)
	if not road.error.is_empty():
		return null
	road.id = _next_id
	_next_id += 1
	roads[road.id] = road
	grid.mark_road(road.cells, 1)
	_rebuild_graph()
	changed.emit()
	return road


func removal_error(id: int) -> String:
	if not roads.has(id):
		return "Choose a street to remove."
	return removal_guard.call(id) if removal_guard.is_valid() else ""


func remove_road(id: int) -> bool:
	if not removal_error(id).is_empty():
		return false
	grid.mark_road(roads[id].cells, -1)
	roads.erase(id)
	for road: Street in roads.values():
		road.crossings.erase(id)
	_rebuild_graph()
	changed.emit()
	return true


func _rebuild_graph() -> void:
	graph = _graph_without(0)
	reachable = _reachable_in(graph)


func reachable_without(id: int) -> Dictionary[Vector2, bool]:
	return _reachable_in(_graph_without(id))


func _graph_without(exclude: int) -> Dictionary[Vector2, PackedVector2Array]:
	var links: Dictionary[Vector2, PackedVector2Array] = {}
	var ends := PackedVector2Array([entrance])
	for road: Street in roads.values():
		if road.id == exclude:
			continue
		ends.append(road.line[0])
		ends.append(road.line[-1])
	for road: Street in roads.values():
		if road.id == exclude:
			continue
		for other: int in road.crossings:
			if other != exclude:
				for junction in road.crossings[other]:
					StreetCrossings.append_joint(ends, junction)
	for road: Street in roads.values():
		if road.id == exclude:
			continue
		# Order endpoints and interior T-junctions along the original street.
		var offsets: Dictionary[Vector2, float] = {}
		for point in ends:
			if not road.bounds.grow(StreetCrossings.EPSILON).has_point(point):
				continue
			var hit := road.nearest(point)
			if hit.distance < 0.05:
				offsets[point] = (
					float(hit.segment)
					+ (
						road.line[hit.segment].distance_to(hit.point)
						/ maxf(
							0.001, road.line[hit.segment].distance_to(road.line[hit.segment + 1])
						)
					)
				)
		var ordered := offsets.keys()
		ordered.sort_custom(func(a: Vector2, b: Vector2) -> bool: return offsets[a] < offsets[b])
		for i in range(1, ordered.size()):
			_link(links, ordered[i - 1], ordered[i])
			_link(links, ordered[i], ordered[i - 1])
	return links


func _reachable_in(links: Dictionary[Vector2, PackedVector2Array]) -> Dictionary[Vector2, bool]:
	var visited: Dictionary[Vector2, bool] = {}
	var pending := PackedVector2Array([entrance])
	while not pending.is_empty():
		var point := pending[-1]
		pending.resize(pending.size() - 1)
		if visited.has(point):
			continue
		visited[point] = true
		for neighbor: Vector2 in links.get(point, PackedVector2Array()):
			if not visited.has(neighbor):
				pending.append(neighbor)

	return visited


func _link(links: Dictionary[Vector2, PackedVector2Array], a: Vector2, b: Vector2) -> void:
	var neighbors := PackedVector2Array(links.get(a, PackedVector2Array()))
	neighbors.append(b)
	links[a] = neighbors
