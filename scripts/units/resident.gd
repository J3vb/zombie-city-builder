class_name Resident
extends Node3D
## One resident's bed, assignment, commute and progress through today's shift.

enum State { HOME, TO_WORK, WORKING, TO_HOME, SHELTERED, BLOCKED }

var resident_id: int
var display_name: String
var home: Building
var job: Building
var state := State.HOME
var cell: Vector2i
var shift_seconds := 0.0
var worked_day := 0
var at_station := false
var hungry := false
var thirsty := false

var _world: World
var _sim_position: Vector2
var _path: Array[Vector2i] = []
var _next := 0


func setup(world: World, house: Building, id: int, given_name: String) -> void:
	_world = world
	resident_id = id
	display_name = given_name
	home = house
	cell = house.plot.door
	_sim_position = world.grid.cell_to_world(cell)
	position = world.to_view(_sim_position)
	hide()


func route_origin() -> Vector2i:
	if _next < _path.size() and not _sim_position.is_equal_approx(_world.grid.cell_to_world(cell)):
		return _path[_next]
	return cell


func occupies(tiles: Array[Vector2i]) -> bool:
	return tiles.has(cell) or tiles.has(route_origin())


func send(path: Array[Vector2i], to_work: bool) -> void:
	var origin := route_origin()
	_next = 0
	_path = path.duplicate()
	if path.is_empty():
		if origin != cell:
			_path.append(origin)
		state = State.BLOCKED
	else:
		if _path[0] == cell:
			_next += 1
		state = State.TO_WORK if to_work else State.TO_HOME
	visible = true


func travel(dt: float, speed: float) -> float:
	while _next < _path.size() and dt > 0.0:
		var end := _world.grid.cell_to_world(_path[_next])
		var rate := speed / maxf(1.0, _world.grid.get_cost(_path[_next]))
		var travel_time := _sim_position.distance_to(end) / rate
		if travel_time > dt:
			_sim_position = _sim_position.move_toward(end, dt * rate)
			dt = 0.0
		else:
			_sim_position = end
			cell = _path[_next]
			_next += 1
			dt -= travel_time
		position = _world.to_view(_sim_position)
	if _next >= _path.size():
		if state == State.TO_WORK:
			state = State.WORKING
		elif state == State.TO_HOME:
			state = State.SHELTERED
			hide()
	return dt


func activity() -> String:
	match state:
		State.TO_WORK:
			return "Walking to work"
		State.WORKING:
			return "Working"
		State.TO_HOME:
			return "Returning to shelter"
		State.BLOCKED:
			return "Route blocked"
		_:
			return "At Station 4" if at_station else "At home"
