class_name Expeditions
extends Node
## One team travels out through a town gate, searches a site and brings its findings back.

enum Phase { IDLE, GATE, LEAVING, OUTBOUND, SEARCH, CHOICE, INBOUND, ENTERING }

const SITES: Array[ExpeditionSite] = [
	preload("res://data/expeditions/market.tres"),
	preload("res://data/expeditions/farm.tres"),
	preload("res://data/expeditions/fuel.tres"),
	preload("res://data/expeditions/police.tres"),
	preload("res://data/expeditions/hospital.tres"),
	preload("res://data/expeditions/relay.tres"),
]

var phase := Phase.IDLE
var site: ExpeditionSite
var team: Array[Resident] = []
var remaining := 0.0
var loot: Dictionary[StringName, int] = {}
var report := ""
var route_blocked := false
var rng := RandomNumberGenerator.new()
var world: World
var _gate: BarrierSegment
var _edge: Vector2i
var _hours := 0
var _kit := false
var _found := false
var _followers := 0
var _dirty := false


func setup(town: World) -> void:
	world = town
	rng.seed = town.map_def.map_seed
	world.grid.changed.connect(_invalidate)
	GameClock.sim_tick.connect(tick)


func _invalidate() -> void:
	_dirty = true


func _open_gate() -> BarrierSegment:
	var entry := world.grid.world_to_cell(world.roads.entrance)
	var closest: BarrierSegment
	var distance := INF
	for gate: BarrierSegment in world.grid.barriers.values():
		if not gate.complete or not gate.def.gate or not gate.opened or gate.close_pending:
			continue
		var d := entry.distance_squared_to(gate.cell)
		if d >= distance:
			continue
		var reachable := true
		for person in team:
			if world.jobs.routes.between(person.route_origin(), gate.cell).is_empty():
				reachable = false
				break
		if reachable:
			closest = gate
			distance = d
	return closest


func _exit_cell() -> Vector2i:
	var edges := world.horde.spawn_cells().duplicate()
	edges.sort_custom(
		func(a: Vector2i, b: Vector2i) -> bool:
			return a.distance_squared_to(_gate.cell) < b.distance_squared_to(_gate.cell)
	)
	for cell: Vector2i in edges:
		if not world.jobs.routes.between(_gate.cell, cell).is_empty():
			return cell
	return Vector2i(-1, -1)


func launch(destination: ExpeditionSite, ids: Array[int], take_kit: bool) -> String:
	var rules := world.plots.rules
	if phase != Phase.IDLE or not SITES.has(destination):
		return "A team is already out or the destination is unavailable."
	if ids.size() < rules.team_min or ids.size() > rules.team_max:
		return "Choose %d to %d residents." % [rules.team_min, rules.team_max]
	var crew: Array[Resident] = []
	for person in world.jobs.residents:
		if (
			ids.has(person.resident_id)
			and person != world.construction.builder
			and person.health > 0
			and not person.unavailable()
		):
			crew.append(person)
	if crew.size() != ids.size():
		return "A selected resident is unavailable."
	team = crew
	_gate = _open_gate()
	if _gate != null:
		_edge = _exit_cell()
	if _gate == null or _edge.x < 0:
		team.clear()
		return "Build or open a reachable gate with a route to the map edge."
	var cost: Dictionary[StringName, int] = {&"food": crew.size(), &"water": crew.size()}
	if take_kit:
		cost.merge(rules.medical_kit_cost)
	if not Economy.spend(cost):
		team.clear()
		return "Need " + BuildingDef.format_cost(cost)
	site = destination
	phase = Phase.GATE
	route_blocked = false
	_kit = take_kit
	_found = false
	_followers = 0
	_hours = 0
	loot.clear()
	report = ""
	for person in team:
		world.jobs.release_assignment(person)
		person.on_trip = true
	_dirty = true
	return ""


func recall() -> void:
	if phase not in [Phase.GATE, Phase.LEAVING]:
		return
	var provisions: Dictionary[StringName, int] = {&"food": team.size(), &"water": team.size()}
	if _kit:
		provisions.merge(world.plots.rules.medical_kit_cost)
	Economy.refund(provisions)
	for person in team:
		if is_instance_valid(person) and person.health > 0:
			person.on_trip = false
			person.seek_shelter(person.home)
	team.clear()
	phase = Phase.IDLE
	route_blocked = false
	report = "Team recalled before departure."
	world.jobs._replan()


func tick(dt: float) -> void:
	if phase == Phase.IDLE or GameClock.ended:
		return
	for i in range(team.size() - 1, -1, -1):
		if not is_instance_valid(team[i]) or team[i].health == 0:
			team.remove_at(i)
	if team.is_empty():
		phase = Phase.IDLE
		report = "The expedition team was lost."
		return
	if phase in [Phase.GATE, Phase.LEAVING, Phase.ENTERING]:
		_walk(dt)
	elif phase != Phase.CHOICE:
		remaining -= dt * 24.0 / world.plots.rules.day_length_seconds
		if remaining <= 0.00001:
			_advance()


func _walk(dt: float) -> void:
	if _dirty:
		_dirty = false
		if phase != Phase.LEAVING:
			_gate = _open_gate()
		route_blocked = phase != Phase.LEAVING and _gate == null
		for person in team:
			var path: Array[Vector2i] = []
			if not route_blocked:
				var end := _edge if phase == Phase.LEAVING else _gate.cell
				path = world.jobs.routes.between(person.route_origin(), end)
			person.send(path, true)
			if path.is_empty():
				route_blocked = true
	if route_blocked:
		return
	var arrived := true
	for person in team:
		person.travel(dt, world.plots.rules.resident_speed)
		if person.state != Resident.State.WORKING:
			arrived = false
	if not arrived:
		return
	if phase == Phase.GATE:
		_edge = _exit_cell()
		phase = Phase.LEAVING
		_dirty = true
	elif phase == Phase.LEAVING:
		for person in team:
			person.off_map = true
			person.hide()
		phase = Phase.OUTBOUND
		remaining = site.hours
	else:
		_finish()


func _advance() -> void:
	match phase:
		Phase.OUTBOUND:
			phase = Phase.SEARCH
			remaining = 1.0
		Phase.SEARCH:
			_hours += 1
			var risk := site.risk
			if GameClock.is_night():
				risk *= world.plots.rules.night_risk_multiplier
			if rng.randf() < risk:
				_injure(world.plots.rules.expedition_injury)
			for item in site.supplies:
				loot[item] = loot.get(item, 0) + rng.randi_range(1, site.supplies[item])
			phase = Phase.CHOICE if _hours >= site.search_hours else Phase.SEARCH
			remaining = 1.0
		Phase.INBOUND:
			phase = Phase.ENTERING
			for person in team:
				person.off_map = false
				person.show()
			_dirty = true


func _injure(amount: int) -> void:
	if amount <= 0:
		return
	if _kit:
		_kit = false
		return
	var person := team[rng.randi_range(0, team.size() - 1)]
	person.health = maxi(1, person.health - amount)
	world.services.exposure(person, site.risk)


func choose(investigate: bool) -> void:
	if phase != Phase.CHOICE:
		return
	var event := site.encounter
	remaining = site.hours
	if investigate:
		for item in event.extra:
			loot[item] = loot.get(item, 0) + event.extra[item]
		_found = event.survivor
		_followers = event.followers
		_injure(event.injury)
		remaining += event.extra_hours
	phase = Phase.INBOUND


func _finish() -> void:
	var delivered: Dictionary[StringName, int] = {}
	for item in loot:
		delivered[item] = Economy.add(item, loot[item])
	report = "%s team returned. Stored %s." % [site.title, BuildingDef.format_cost(delivered)]
	if _found:
		var recruit := world.jobs.arrive()
		if recruit != null:
			recruit.arrive_at(_gate.cell)
		report += (
			" %s joined the town." % recruit.display_name
			if recruit != null
			else " The town is full."
		)
	if _followers > 0:
		for i in _followers:
			world.zombies.spawn(world.grid.cell_to_world(_edge), world.horde.walker)
		report += " Walkers followed the team."
	if _kit:
		Economy.refund(world.plots.rules.medical_kit_cost)
	for person in team:
		person.on_trip = false
		person.seek_shelter(person.home)
	team.clear()
	phase = Phase.IDLE
	world.jobs._replan()
	if world.construction.builder == null and not world.jobs.residents.is_empty():
		for candidate in world.jobs.residents:
			if not candidate.unavailable():
				world.construction.replace_builder(candidate)
				break


func status() -> String:
	if phase == Phase.IDLE:
		return report
	if route_blocked:
		return "Team waiting for an open gate and a clear route."
	var leg: String = [
		"",
		"Meeting at gate",
		"Walking to map edge",
		"Travelling",
		"Searching",
		"Team needs a decision",
		"Returning",
		"Walking to town gate"
	][phase]
	return (
		"%s · %s" % [site.title, leg]
		if phase not in [Phase.OUTBOUND, Phase.SEARCH, Phase.INBOUND]
		else "%s · %s · %.1f hours" % [site.title, leg, maxf(0.0, remaining)]
	)
