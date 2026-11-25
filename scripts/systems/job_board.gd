class_name JobBoard
extends Node3D
## Assigns residents to reachable workplaces and settles completed shifts at dawn.

const RESIDENT := preload("res://scenes/units/resident.tscn")

var residents: Array[Resident] = []
var sites: Array[Building] = []
var routes := ResidentRoutes.new()
var pending: Dictionary[StringName, int] = {}
var last_output: Dictionary[StringName, int] = {}
var last_overflow: Dictionary[StringName, int] = {}
var last_consumed: Dictionary[StringName, int] = {}
var last_shortage: Dictionary[StringName, int] = {}
var last_dawn := 0
var world: World
var rules: BalanceDef
var _next_id := 1
var _staff: Dictionary[Building, Resident] = {}
var _closed: Dictionary[Building, bool] = {}
var _dirty := true
var _off_duty := false


func setup(owner_world: World) -> void:
	world = owner_world
	rules = world.plots.rules
	last_dawn = GameClock.day
	routes.setup(world.grid)
	world.grid.changed.connect(_replan)
	EventBus.building_placed.connect(_placed)
	EventBus.building_destroyed.connect(_removed)
	EventBus.day_started.connect(_dawn)
	GameClock.sim_tick.connect(_tick)


func _exit_tree() -> void:
	if world == null:
		return
	EventBus.building_placed.disconnect(_placed)
	EventBus.building_destroyed.disconnect(_removed)
	EventBus.day_started.disconnect(_dawn)
	GameClock.sim_tick.disconnect(_tick)


func _replan() -> void:
	_dirty = true


func _placed(building: Building) -> void:
	if building.get_parent() != world.buildings or building.is_queued_for_deletion():
		return
	_dirty = true
	if building is DefenseTower or building.def.shift_yields.size() > 0:
		sites.append(building)
	if building.plot == null:
		return
	for resident in residents:
		if resident.home == null:
			resident.home = building
			return
	arrive(building)


func arrive(building: Building = null) -> Resident:
	if world.safety.people.size() >= rules.resident_limit:
		return null
	var id := _next_id
	_next_id += 1
	var given := "Resident %d" % id
	if id <= rules.resident_names.size():
		given = rules.resident_names[id - 1]
	var resident := RESIDENT.instantiate() as Resident
	resident.setup(world, building if building != null else world.command_post, id, given)
	if building == null:
		resident.home = null
		resident.at_station = true
	add_child(resident)
	residents.append(resident)
	_dirty = true
	return resident


func _removed(building: Building) -> void:
	if building.get_parent() != world.buildings:
		return
	_dirty = true
	world.safety.shelter_removed(building)
	sites.erase(building)
	_closed.erase(building)
	var worker := worker_at(building)
	if worker != null:
		_set_job(worker, null)
	for resident in residents:
		if resident.home == building:
			resident.home = null
			_set_job(resident, null)
			for house: Building in world.buildings.get_children():
				if (
					house.plot != null
					and house.target_level != 1
					and not house.is_queued_for_deletion()
					and tenant(house) == null
				):
					resident.home = house
					break


func release_assignment(person: Resident) -> void:
	_set_job(person, null)


func remove_worker(person: Resident) -> void:
	_set_job(person, null)
	residents.erase(person)
	if person.home != null and person.home.plot != null:
		for displaced in residents:
			if displaced.home == null:
				displaced.home = person.home
				break


func tenant(house: Building) -> Resident:
	for resident in residents:
		if resident.home == house:
			return resident
	return null


func worker_at(site: Building) -> Resident:
	return _staff.get(site)


func hiring_closed(site: Building) -> bool:
	return _closed.has(site)


func toggle_hiring(site: Building) -> void:
	if not sites.has(site):
		return
	if _closed.has(site):
		_closed.erase(site)
	else:
		_closed[site] = true
		var worker := worker_at(site)
		if worker != null:
			_set_job(worker, null)
	_dirty = true


func assign(resident: Resident, site: Building) -> bool:
	if (
		resident == world.construction.builder
		or resident.on_trip
		or not residents.has(resident)
		or resident.home == null
		or not sites.has(site)
	):
		return false
	if routes.to_building(resident.route_origin(), site).is_empty():
		return false
	_closed.erase(site)
	if resident.job == site:
		return true
	var previous := worker_at(site)
	if previous != null:
		_set_job(previous, null)
	_set_job(resident, site)
	return true


func _set_job(resident: Resident, site: Building) -> void:
	if resident.job != null:
		_staff.erase(resident.job)
	if resident.on_watch():
		resident.shelter = null
		resident.show()
	resident.job = site
	resident.shift_seconds = 0.0
	if site != null:
		_staff[site] = resident
	_dirty = true


func _find_job(resident: Resident) -> void:
	var origin := resident.route_origin()
	var nearest: Building
	var distance := INF
	for site in sites:
		if _closed.has(site) or _staff.has(site):
			continue
		var d := world.grid.cell_to_world(origin).distance_squared_to(site.sim_center())
		if d >= distance or routes.to_building(origin, site).is_empty():
			continue
		nearest = site
		distance = d
	if nearest != null:
		_set_job(resident, nearest)


func _plan(resident: Resident) -> void:
	var origin := resident.route_origin()
	if resident.job is DefenseTower and not resident.retreating and resident.home != null:
		if not resident.on_watch():
			resident.send(routes.to_building(origin, resident.job), true)
		return
	if (
		not resident.retreating
		and not _off_duty
		and resident.home != null
		and resident.worked_day != GameClock.day
	):
		if resident.job == null:
			_find_job(resident)
		if resident.job != null:
			resident.send(routes.to_building(origin, resident.job), true)
			return
	resident.seek_shelter(resident.home)


func _tick(dt: float) -> void:
	if residents.is_empty():
		return
	var off_duty := GameClock.time_of_day >= rules.dusk_at
	var replan := _dirty or off_duty != _off_duty
	_off_duty = off_duty
	_dirty = false
	for resident in residents:
		if resident == world.construction.builder or resident.on_trip:
			continue
		if resident.update_retreat() or replan:
			_plan(resident)
		var on_site := resident.travel(dt, rules.resident_speed)
		if resident.state == Resident.State.WORKING and resident.job is DefenseTower:
			resident.stand_watch()
			continue
		if resident.state != Resident.State.WORKING or on_site <= 0.0:
			continue
		resident.shift_seconds += on_site * resident.work_pace()
		if resident.shift_seconds < rules.shift_seconds:
			continue
		var site := resident.job
		var item := site.def.output_resource
		var quantity := site.shift_output()
		pending[item] = pending.get(item, 0) + quantity
		resident.worked_day = GameClock.day
		_plan(resident)


func _dawn(day: int) -> void:
	if day <= last_dawn:
		return
	last_dawn = day
	var harvested := pending.duplicate()
	last_output.clear()
	last_overflow.clear()
	pending.clear()
	last_consumed.clear()
	last_shortage.clear()
	for item in harvested:
		var received := Economy.add(item, harvested[item])
		if received > 0:
			last_output[item] = received
		if harvested[item] > received:
			last_overflow[item] = harvested[item] - received
	for resident in world.safety.people:
		resident.shift_seconds = 0.0
		if resident.off_map:
			continue
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
		resident.update_ration(hungry, thirsty)
		resident.wake_up()
	_dirty = true


func blocks_placement(cells: Array[Vector2i]) -> bool:
	if (
		world != null
		and world.construction.builder != null
		and world.construction.builder.occupies(cells)
	):
		return true
	for resident in residents:
		if resident.occupies(cells):
			return true
	return false
