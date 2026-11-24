class_name RoadNetwork
extends Node
## Owns street geometry and the junction graph. Grid keeps roads open to walkers.

signal changed

var roads: Dictionary[int, Street] = {}
var entrance: Vector2
var width: float
var min_segment: float
var snap_radius: float
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
	var bounds := post.sim_bounds()
	entrance = Vector2(bounds.get_center().x, bounds.end.y + width * 0.5)


func nearest(point: Vector2, limit: float) -> Dictionary:
	var hit := {}
	for road: Street in roads.values():
		var candidate := road.nearest(point)
		if candidate.distance <= limit:
			limit = candidate.distance
			hit = candidate
	return hit


func snap_endpoint(point: Vector2) -> Vector2:
	if point.distance_to(entrance) <= snap_radius:
		return entrance
	var hit := nearest(point, snap_radius)
	if hit.is_empty():
		return point
	var road: Street = hit.road
	for end: Vector2 in [road.line[0], road.line[-1]]:
		if point.distance_to(end) <= snap_radius:
			return end
	return hit.point


func preview(points: PackedVector2Array) -> Street:
	var road := Street.new()
	road.controls = points.duplicate()
	if points.size() < 2:
		road.error = "Click at least two points."
		return road
	road.controls[0] = snap_endpoint(points[0])
	road.controls[-1] = snap_endpoint(points[-1])
	for i in range(1, points.size()):
		if road.controls[i].distance_to(road.controls[i - 1]) < min_segment:
			road.error = "Street points are too close."
			return road
	for i in range(1, road.controls.size() - 1):
		var incoming := road.controls[i - 1].direction_to(road.controls[i])
		var outgoing := road.controls[i].direction_to(road.controls[i + 1])
		if incoming.dot(outgoing) < -0.94:
			road.error = "The street turns back on itself."
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
	if _overlaps_street(road):
		road.error = "Join an existing street at an endpoint or a T-junction."
	return road


func add_road(points: PackedVector2Array) -> Street:
	var road := preview(points)
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
	_rebuild_graph()
	changed.emit()
	return true


func _overlaps_street(road: Street) -> bool:
	for existing: Street in roads.values():
		var joints := PackedVector2Array()
		for end: Vector2 in [road.line[0], road.line[-1]]:
			if existing.nearest(end).distance < 0.05:
				joints.append(end)
		for i in road.line.size() - 1:
			for j in existing.line.size() - 1:
				var pair := Geometry2D.get_closest_points_between_segments(
					road.line[i], road.line[i + 1], existing.line[j], existing.line[j + 1]
				)
				if pair[0].distance_to(pair[1]) >= width:
					continue
				var at_joint := false
				for joint in joints:
					if (
						pair[0].distance_to(joint) <= width * 1.5
						and pair[1].distance_to(joint) <= width * 1.5
					):
						at_joint = true
						break
				if not at_joint:
					return true
	return false


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
		# Order endpoints and interior T-junctions along the original street.
		var offsets: Dictionary[Vector2, float] = {}
		for point in ends:
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
