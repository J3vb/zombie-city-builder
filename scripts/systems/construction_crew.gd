class_name ConstructionCrew
extends Node3D
## Station 4's builder visits paid projects in order and resumes unfinished work at dawn.

var builder: Resident
var target: Building
var segment: BarrierSegment
var repair_job := false
var projects: Array[Building] = []
var _retry := 0.0
var _blocked: Dictionary[Building, bool] = {}
var _world: World
var _dirty := true
var _after_dusk := false


func setup(world: World) -> void:
	_world = world
	if not world.restoring:
		builder = JobBoard.RESIDENT.instantiate() as Resident
		builder.setup(world, world.command_post, 0, world.plots.rules.builder_name)
		builder.at_station = true
		add_child(builder)
	world.grid.changed.connect(_replan)
	EventBus.building_destroyed.connect(_removed)
	GameClock.sim_tick.connect(tick)


func _exit_tree() -> void:
	if _world != null:
		GameClock.sim_tick.disconnect(tick)
		EventBus.building_destroyed.disconnect(_removed)


func site_changed(site: Building) -> void:
	if site.is_queued_for_deletion() or site.target_level == 0:
		_removed(site)
	elif not projects.has(site):
		projects.append(site)
		_replan()


func _removed(site: Building) -> void:
	if site == target:
		target = null
	if projects.has(site):
		projects.erase(site)
		_blocked.erase(site)
		_replan()


func replace_builder(person: Resident) -> void:
	builder = person
	target = null
	if builder != null:
		_world.jobs.release_assignment(builder)
	_replan()


func _replan() -> void:
	_dirty = true


func _choose() -> void:
	var origin := builder.route_origin()
	var routes := _world.jobs.routes
	target = null
	segment = null
	repair_job = false
	_blocked.clear()
	if not _after_dusk and not builder.retreating:
		for site in projects:
			var path := routes.to_building(origin, site)
			if path.is_empty():
				_blocked[site] = true
				continue
			target = site
			builder.send(path, true)
			return
		for order in _world.perimeter.orders:
			var path := routes.to_edges(origin, [order.cell])
			if not path.is_empty():
				segment = order
				builder.send(path, true)
				return
		for damaged in _world.perimeter.damaged:
			if not _world.perimeter.safe_to_repair(damaged):
				continue
			var path := routes.to_edges(origin, [damaged.cell])
			if not path.is_empty():
				segment = damaged
				repair_job = true
				builder.send(path, true)
				return
	builder.seek_shelter(_world.command_post)


func tick(dt: float) -> void:
	if (
		builder == null
		or not is_instance_valid(_world.command_post)
		or _world.command_post.is_queued_for_deletion()
	):
		return
	var after_dusk := GameClock.time_of_day >= _world.plots.rules.dusk_at
	if (
		not after_dusk
		and not _world.perimeter.damaged.is_empty()
		and target == null
		and segment == null
	):
		_retry -= dt
		if _retry <= 0.0:
			_dirty = true
			_retry = _world.plots.rules.repair_retry_seconds
	if (
		repair_job
		and (
			not _world.perimeter.damaged.has(segment)
			or not _world.perimeter.safe_to_repair(segment)
		)
	):
		_dirty = true
	if builder.update_retreat() or _dirty or after_dusk != _after_dusk:
		_after_dusk = after_dusk
		_dirty = false
		_choose()
	var remaining := builder.travel(dt, _world.plots.rules.resident_speed)
	if builder.state == Resident.State.WORKING and remaining > 0.0:
		if target != null:
			target.add_build_work(remaining * builder.work_pace())
		elif repair_job:
			_world.perimeter.repair(segment, remaining * builder.work_pace())
		elif segment != null:
			_world.perimeter.add_work(segment, remaining * builder.work_pace())


func status(site: Building) -> String:
	if builder == null or builder.retreating:
		return "No surviving builder" if builder == null else "Builder taking shelter"
	if GameClock.speed == 0:
		return "Clock paused"
	if GameClock.time_of_day >= _world.plots.rules.dusk_at:
		return "Builder returns at dawn"
	if _blocked.has(site):
		return "No walkable route to site"
	if site != target:
		return "Waiting for the builder"
	return (
		"%s is building" % builder.display_name
		if builder.state == Resident.State.WORKING
		else "%s is walking to site" % builder.display_name
	)
