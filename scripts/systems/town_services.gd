class_name TownServices
extends Node
## Clinic, containment and the fuel-powered night lighting of this settlement.

var clinic: ServiceDef
var cold_room: ServiceDef
var generator: ServiceDef
var floodlight: ServiceDef

var sites: Array[Building] = []
var supply := 0
var demand := 0
var rng := RandomNumberGenerator.new()
var world: World
var _fuel: Dictionary[Building, float] = {}
var _lights: Dictionary[Building, OmniLight3D] = {}
var _disabled: Dictionary[Building, bool] = {}
var _pulse := 0.0


func setup(town: World) -> void:
	world = town
	clinic = load("res://data/buildings/clinic.tres") as ServiceDef
	cold_room = load("res://data/buildings/cold_room.tres") as ServiceDef
	generator = load("res://data/buildings/generator.tres") as ServiceDef
	floodlight = load("res://data/buildings/floodlight.tres") as ServiceDef
	rng.seed = town.map_def.map_seed
	world.grid.changed.connect(_route_patients)
	EventBus.building_placed.connect(_placed)
	EventBus.building_destroyed.connect(_removed)
	GameClock.sim_tick.connect(tick)


func _route_patients() -> void:
	for person in world.safety.people:
		if person.ward != null and person.state != Resident.State.SHELTERED:
			person.send(world.jobs.routes.to_building(person.route_origin(), person.ward), false)


func _placed(site: Building) -> void:
	if site.get_parent() != world.buildings or not site.def is ServiceDef or sites.has(site):
		return
	sites.append(site)
	if site.def == generator:
		_fuel[site] = 0.0
	if site.def == floodlight:
		var lamp := OmniLight3D.new()
		lamp.omni_range = world.view_tile() * floodlight.light_tiles
		lamp.light_energy = 3.0
		lamp.light_color = Color("#ffe3a6")
		lamp.visible = false
		site.add_child(lamp)
		lamp.position = world.to_view(site.sim_center()) + Vector3.UP * site.def.view_height
		_lights[site] = lamp


func _removed(site: Building) -> void:
	if not sites.has(site):
		return
	sites.erase(site)
	_fuel.erase(site)
	_lights.erase(site)
	_disabled.erase(site)
	if _lights.is_empty():
		supply = 0
		demand = 0
	for person in world.safety.people:
		if person.ward == site:
			release(person)


func exposure(person: Resident, chance: float) -> void:
	if person.ember == 0 and rng.randf() < chance:
		person.ember = 1
		person.ember_hours = 0.0


func medic_on_duty() -> bool:
	for site in sites:
		if site.def == clinic:
			var medic := world.jobs.worker_at(site)
			if medic != null and medic.job == site and medic.state == Resident.State.WORKING:
				return true
	return false


func free_ward() -> Building:
	for site in sites:
		if site.def != cold_room:
			continue
		var taken := 0
		for person in world.safety.people:
			if person.ward == site:
				taken += 1
		if taken < cold_room.beds:
			return site
	return null


func isolate(person: Resident) -> bool:
	var room := free_ward()
	if room == null or person.unavailable():
		return false
	var path := world.jobs.routes.to_building(person.route_origin(), room)
	if path.is_empty():
		return false
	if person == world.construction.builder:
		var successor: Resident
		for other in world.jobs.residents:
			if other != person and not other.unavailable():
				successor = other
				break
		world.construction.replace_builder(successor)
	world.jobs.release_assignment(person)
	person.ward = room
	person.shelter = room
	person.send(path, false)
	return true


func release(person: Resident) -> void:
	person.ward = null
	if world.construction.builder == null:
		world.construction.replace_builder(person)
	person.seek_shelter(person.home)
	world.jobs._replan()


func treat(person: Resident) -> bool:
	if person.off_map or not person.diagnosed or not medic_on_duty() or person.ember_hours < 0.0:
		return false
	if not Economy.spend(world.plots.rules.medical_kit_cost):
		return false
	person.ember_hours -= world.plots.rules.medicine_delay_hours
	return true


func tick(dt: float) -> void:
	var hours := dt * 24.0 / world.plots.rules.day_length_seconds
	if not sites.is_empty():
		_power(dt, hours)
	var staffed := medic_on_duty()
	for person: Resident in world.safety.people.duplicate():
		if person.ward != null and person.state != Resident.State.SHELTERED:
			person.travel(dt, world.plots.rules.resident_speed)
		if person.ember == 0:
			continue
		person.ember_hours += hours
		person.diagnosed = person.diagnosed or (staffed and not person.off_map) or person.ember >= 2
		if person.ember_hours < world.plots.rules.ember_stage_hours:
			continue
		person.ember_hours -= world.plots.rules.ember_stage_hours
		person.ember += 1
		person.diagnosed = true
		if person.ember == 3:
			var contained := person.ward != null and person.state == Resident.State.SHELTERED
			if not contained and not person.off_map:
				world.zombies.spawn(person.sim_position(), world.horde.walker)
			person.health = 0
			world.safety.lose(person, world)


func _power(dt: float, hours: float) -> void:
	demand = 0
	supply = 0
	for lamp in _lights:
		if GameClock.is_night() and not _disabled.has(lamp):
			demand += floodlight.demand
	for gen in _fuel:
		if demand > 0 and not _disabled.has(gen):
			if _fuel[gen] <= 0.0 and Economy.get_amount(&"fuel") > 0:
				Economy.add(&"fuel", -1)
				_fuel[gen] = generator.fuel_hours
				if world.campaign.has_tech(&"rebuild"):
					_fuel[gen] *= world.plots.rules.rebuild_fuel_multiplier
			if _fuel[gen] > 0.0:
				supply += generator.supply
				_fuel[gen] -= hours
	_pulse -= dt
	for site in _lights:
		var lamp := _lights[site]
		lamp.visible = demand > 0 and supply >= demand and not _disabled.has(site)
		if lamp.visible and _pulse <= 0.0:
			world.zombies.alert(site.sim_center(), world.grid.tile_size * floodlight.light_tiles)
	if _pulse <= 0.0:
		_pulse = world.plots.rules.lamp_pulse_seconds


func toggle(site: Building) -> void:
	if _disabled.has(site):
		_disabled.erase(site)
	else:
		_disabled[site] = true
	_power(0.0, 0.0)


func operating(site: Building) -> bool:
	return not _disabled.has(site)


func power_text() -> String:
	return "Power %d / %d demand · Fuel %d" % [supply, demand, Economy.get_amount(&"fuel")]


func health_text(person: Resident) -> String:
	if person.ember == 2:
		return "Fever"
	if person.ember == 1 and person.diagnosed:
		return "Warm · clinic confirmed"
	return "No visible signs"
