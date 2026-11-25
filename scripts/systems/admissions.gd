class_name Admissions
extends Node
## One waiting refugee per staffed checkpoint. The lamp and the clinic reveal different signs.

var world: World
var waiting: Dictionary[BarrierSegment, Dictionary] = {}
var rng := RandomNumberGenerator.new()
var report := ""


func setup(town: World) -> void:
	world = town
	rng.seed = town.map_def.map_seed
	EventBus.day_started.connect(_dawn)
	GameClock.sim_tick.connect(_tick)


func _dawn(day: int) -> void:
	if day % world.plots.rules.refugee_interval_days != 0:
		return
	for segment: BarrierSegment in world.grid.barriers.values():
		if segment.complete and segment.def == Perimeter.CHECKPOINT and not waiting.has(segment):
			var stage := 0
			if rng.randf() < world.plots.rules.refugee_ember_chance:
				stage = rng.randi_range(1, 2)
			waiting[segment] = {"stage": stage, "hours": 0.0, "seen": false, "checked": false}
			report = "A refugee is waiting at the checkpoint."
			return


func _tick(dt: float) -> void:
	for gate in waiting.keys():
		if world.grid.barriers.get(gate.cell) != gate:
			waiting.erase(gate)
			report = "The checkpoint was lost. Its visitor left."
			continue
		var record: Dictionary = waiting[gate]
		if gate.post == null:
			continue
		var guard := world.jobs.worker_at(gate.post)
		if guard == null or not guard.on_watch():
			continue
		record.hours += dt * 24.0 / world.plots.rules.day_length_seconds
		if record.hours >= world.plots.rules.inspection_hours:
			record.checked = true
			record.seen = (
				record.seen
				or (record.stage == 2 or (record.stage == 1 and world.services.medic_on_duty()))
			)


func status(gate: BarrierSegment) -> String:
	if not waiting.has(gate):
		return "Holding pen empty"
	var record: Dictionary = waiting[gate]
	if not record.checked:
		return "Refugee in holding pen · waiting for a guard to finish inspection"
	if record.seen:
		return (
			"Inspection finished · " + ("Fever" if record.stage == 2 else "Warm · clinic confirmed")
		)
	return "Inspection finished · no visible signs"


func decide(gate: BarrierSegment, choice: StringName) -> String:
	if not waiting.has(gate) or not waiting[gate].checked:
		return "The guard must finish the inspection."
	if choice not in [&"accept", &"isolate", &"decline"]:
		return "Unknown decision."
	if choice == &"decline":
		waiting.erase(gate)
		report = "The visitor left the Ford."
		return report
	var reason := _blocker(choice, gate)
	if not reason.is_empty():
		return reason
	var person := world.jobs.arrive()
	var entry := _entry(gate)
	person.arrive_at(entry)
	var record: Dictionary = waiting[gate]
	person.ember = record.stage
	person.diagnosed = record.seen
	if choice == &"isolate":
		world.services.isolate(person)
	waiting.erase(gate)
	report = "%s joined the town." % person.display_name
	return report


func _entry(gate: BarrierSegment) -> Vector2i:
	var home := world.grid.world_to_cell(world.roads.entrance)
	var path := world.jobs.routes.to_edges(home, [gate.cell])
	return path.back() if not path.is_empty() else Vector2i(-1, -1)


func _blocker(choice: StringName, gate: BarrierSegment) -> String:
	if world.safety.people.size() >= world.resident_capacity():
		return "The settlement is full."
	var entry := _entry(gate)
	if entry.x < 0:
		return "No clear route into town."
	if choice == &"isolate":
		var ward := world.services.free_ward()
		if ward == null or world.jobs.routes.to_building(entry, ward).is_empty():
			return "A reachable Cold Room bed is required."
	return ""
