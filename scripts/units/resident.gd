class_name Resident
extends Node3D
## One resident's bed, assignment, commute and progress through today's shift.

enum State { HOME, TO_WORK, WORKING, TO_HOME, SHELTERED, BLOCKED }

var health: int
var threat_near := false
var retreating := false
var shelter: Building
var resident_id: int
var display_name: String
var home: Building
var job: Building
var state := State.HOME
var cell: Vector2i
var shift_seconds := 0.0
var worked_day := 0
var at_station := false
var missed_rations := 0
var hungry := false
var ember := 0
var ember_hours := 0.0
var diagnosed := false
var ward: Building
var on_trip := false
var off_map := false
var thirsty := false
var sleep_seconds := 0.0
var tired := false

var _world: World
var _sim_position: Vector2
var _path: Array[Vector2i] = []
var _next := 0


func setup(world: World, house: Building, id: int, given_name: String) -> void:
	_world = world
	resident_id = id
	display_name = given_name
	home = house
	shelter = house
	health = world.plots.rules.resident_health
	world.safety.people.append(self)
	cell = house.plot.door if house.plot != null else world.grid.world_to_cell(world.roads.entrance)
	_sim_position = world.grid.cell_to_world(cell)
	position = world.to_view(_sim_position)
	hide()


func arrive_at(entry: Vector2i) -> void:
	cell = entry
	_sim_position = _world.grid.cell_to_world(entry)
	position = _world.to_view(_sim_position)
	shelter = null
	state = State.BLOCKED
	show()


func sim_position() -> Vector2:
	return _sim_position


func stand_watch() -> void:
	if not on_watch():
		shelter = job
		position = _world.to_view(job.sim_center()) + Vector3.UP * (job.def as TowerDef).deck_height
		show()


func on_watch() -> bool:
	return job is DefenseTower and shelter == job and state == State.WORKING


func unavailable() -> bool:
	return on_trip or ward != null


func exposed() -> bool:
	return (
		not off_map
		and health > 0
		and state != State.HOME
		and state != State.SHELTERED
		and not on_watch()
	)


func take_hit(amount: int, ember_chance: float = 0.0) -> void:
	if not exposed() or amount <= 0:
		return
	health = maxi(0, health - amount)
	if health == 0:
		_world.safety.lose(self, _world)
	elif ember_chance > 0.0:
		_world.services.exposure(self, ember_chance)


func update_retreat() -> bool:
	var should_retreat := (
		(threat_near and not on_watch()) or (retreating and state == State.TO_HOME)
	)
	if should_retreat == retreating:
		return false
	retreating = should_retreat
	$Alert.visible = retreating
	return true


func seek_shelter(preferred: Building) -> void:
	var origin := route_origin()
	var routes := _world.jobs.routes
	var path := routes.to_building(origin, preferred)
	shelter = preferred
	if preferred != _world.command_post and (path.is_empty() or retreating):
		var fallback := routes.to_building(origin, _world.command_post)
		if path.is_empty() or (not fallback.is_empty() and fallback.size() < path.size()):
			shelter = _world.command_post
			path = fallback
	at_station = shelter == _world.command_post
	send(path, false)


func route_origin() -> Vector2i:
	if _next < _path.size() and not _sim_position.is_equal_approx(_world.grid.cell_to_world(cell)):
		return _path[_next]
	return cell


func occupies(tiles: Array[Vector2i]) -> bool:
	return not off_map and (tiles.has(cell) or tiles.has(route_origin()))


func send(path: Array[Vector2i], to_work: bool) -> void:
	position = _world.to_view(_sim_position)
	if to_work:
		shelter = null
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
	if is_sleeping():
		sleep_seconds = minf(_world.plots.rules.sleep_seconds, sleep_seconds + dt)
	return dt


func update_ration(condition_hungry: bool, condition_thirsty: bool) -> void:
	hungry = condition_hungry
	thirsty = condition_thirsty
	if hungry or thirsty:
		missed_rations += int(hungry) + int(thirsty)
	else:
		missed_rations = 0


func is_sleeping() -> bool:
	return (
		GameClock.time_of_day >= _world.plots.rules.dusk_at
		and state in [State.HOME, State.SHELTERED]
		and is_instance_valid(shelter)
		and not shelter.is_queued_for_deletion()
	)


func wake_up() -> void:
	tired = not is_equal_approx(sleep_seconds, _world.plots.rules.sleep_seconds)
	sleep_seconds = 0.0


func work_pace() -> float:
	var rules := _world.plots.rules
	var fatigue := rules.fatigue_pace_loss if tired else 0.0
	if ember == 2:
		fatigue += rules.fever_pace_loss
	return maxf(rules.minimum_work_pace, 1.0 - missed_rations * rules.shortage_pace_loss - fatigue)


func activity() -> String:
	if ward != null:
		return "In quarantine" if state == State.SHELTERED else "Going to the Cold Room"
	if on_trip:
		return "On expedition" if off_map else "Walking with expedition team"
	return _town_activity()


func _town_activity() -> String:
	match state:
		State.TO_WORK:
			return "Walking to work"
		State.WORKING:
			return "On watch" if on_watch() else "Working"
		State.TO_HOME:
			if retreating:
				return "Fleeing to Station 4" if at_station else "Fleeing home"
			return "Returning to shelter"
		State.BLOCKED:
			return "Escape route blocked" if retreating else "Route blocked"
		_:
			return _shelter_activity()


func _shelter_activity() -> String:
	if is_sleeping():
		return "Sleeping at Station 4" if at_station else "Sleeping at home"
	if retreating:
		return "Sheltering from Walkers"
	return "At Station 4" if at_station else "At home"


func settle_needs(
	rules: BalanceDef,
	last_consumed: Dictionary[StringName, int],
	last_shortage: Dictionary[StringName, int]
) -> void:
	var hungry := false
	var thirsty := false
	for item in rules.daily_ration:
		var need := rules.daily_ration[item]
		var amount := mini(Economy.get_amount(item), need)
		if amount > 0:
			Economy.add(item, -amount)
		last_consumed[item] = last_consumed.get(item, 0) + amount
		if amount < need:
			last_shortage[item] = last_shortage.get(item, 0) + need - amount
		if item == &"food":
			hungry = amount < need
		elif item == &"water":
			thirsty = amount < need
	update_ration(hungry, thirsty)
	wake_up()
