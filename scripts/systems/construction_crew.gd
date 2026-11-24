class_name ConstructionCrew
extends Node3D
## Station 4's builder visits paid projects in order and resumes unfinished work at dawn.

var builder: Resident
var target: Building
var projects: Array[Building] = []
var _blocked: Dictionary[Building, bool] = {}
var _world: World
var _dirty := true
var _after_dusk := false


func setup(world: World) -> void:
	_world = world
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


func _replan() -> void:
	_dirty = true


func _choose() -> void:
	var origin := builder.route_origin()
	var routes := _world.jobs.routes
	target = null
	_blocked.clear()
	if not _after_dusk:
		for site in projects:
			var path := routes.to_building(origin, site)
			if path.is_empty():
				_blocked[site] = true
				continue
			target = site
			builder.send(path, true)
			return
	builder.send(routes.to_building(origin, _world.command_post), false)


func tick(dt: float) -> void:
	if not is_instance_valid(_world.command_post) or _world.command_post.is_queued_for_deletion():
		return
	var after_dusk := GameClock.time_of_day >= _world.plots.rules.dusk_at
	if _dirty or after_dusk != _after_dusk:
		_after_dusk = after_dusk
		_dirty = false
		_choose()
	var remaining := builder.travel(dt, _world.plots.rules.resident_speed)
	if target != null and builder.state == Resident.State.WORKING and remaining > 0.0:
		target.add_build_work(remaining * builder.work_pace())


func status(site: Building) -> String:
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
