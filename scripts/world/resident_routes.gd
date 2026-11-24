class_name ResidentRoutes
extends RefCounted
## Routes residents across the same walkable cells used by the town simulation.

var grid: Grid
var _astar := AStarGrid2D.new()
var _dirty := true


func setup(town_grid: Grid) -> void:
	grid = town_grid
	_astar.region = Rect2i(Vector2i.ZERO, grid.size)
	_astar.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_NEVER
	_astar.default_compute_heuristic = AStarGrid2D.HEURISTIC_MANHATTAN
	_astar.default_estimate_heuristic = AStarGrid2D.HEURISTIC_MANHATTAN
	_astar.update()
	grid.changed.connect(invalidate)


func invalidate() -> void:
	_dirty = true


func to_building(start: Vector2i, building: Building) -> Array[Vector2i]:
	var empty: Array[Vector2i] = []
	if (
		grid.get_cost(start) <= 0
		or not is_instance_valid(building)
		or building.is_queued_for_deletion()
	):
		return empty
	_sync()
	if building.plot != null:
		var door := building.plot.door
		return _astar.get_id_path(start, door) if grid.get_cost(door) > 0 else empty
	return to_edges(start, building.cells)


func _sync() -> void:
	if _dirty:
		for y in grid.size.y:
			for x in grid.size.x:
				var cell := Vector2i(x, y)
				var cost := grid.get_cost(cell)
				_astar.set_point_solid(cell, cost <= 0)
				if cost > 0:
					_astar.set_point_weight_scale(cell, cost)
		_dirty = false


func to_edges(start: Vector2i, cells: Array[Vector2i]) -> Array[Vector2i]:
	_sync()
	var best: Array[Vector2i] = []
	var best_cost := INF
	var ends: Dictionary[Vector2i, bool] = {}
	for cell in cells:
		for offset: Vector2i in [Vector2i.UP, Vector2i.LEFT, Vector2i.RIGHT, Vector2i.DOWN]:
			var end := cell + offset
			if grid.get_cost(end) <= 0 or ends.has(end):
				continue
			ends[end] = true
			var path := _astar.get_id_path(start, end)
			if path.is_empty():
				continue
			var cost := 0.0
			for step in path:
				cost += grid.get_cost(step)
			if cost < best_cost:
				best_cost = cost
				best = path
	return best
