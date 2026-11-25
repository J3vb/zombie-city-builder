extends TestCase
## Check hidden cases, quarantine, staffed inspections and fuel-driven night lighting.


func _residents(w: World, count: int) -> Array[Resident]:
	var p := w.roads.entrance
	w.roads.add_road(PackedVector2Array([p, p + Vector2.DOWN * 700]))
	for i in count:
		var plot := w.plots.reserve(p + Vector2(8, 100 + i * 135), w.plots.rules.plot_frontage)
		w.spawn_building(w.plots.house_def, plot.house_cells[0], plot)
	return w.jobs.residents


func test_hidden_case_clinic_medicine_and_contained_turn() -> void:
	var fx := WorldFixture.new()
	var w := fx.create()
	var people := _residents(w, 2)
	var patient := people[1]
	w.services.exposure(patient, 1.0)
	w.services.tick(0.1)
	assert_eq(w.services.health_text(patient), "No visible signs")
	var clinic := w.spawn_building(w.services.clinic, Vector2i(56, 65))
	assert_true(w.jobs.assign(people[0], clinic))
	w.jobs._tick(60.0)
	w.services.tick(0.1)
	assert_true(w.services.medic_on_duty() and patient.diagnosed)
	var medicine := Economy.get_amount(&"medicine")
	assert_true(w.services.treat(patient))
	assert_true(not w.services.treat(patient))
	assert_eq(Economy.get_amount(&"medicine"), medicine - 1)
	var ward := w.spawn_building(w.services.cold_room, Vector2i(55, 69))
	assert_true(ward != null and w.services.isolate(patient))
	w.services.tick(90.0)
	assert_eq(patient.state, Resident.State.SHELTERED)
	patient.ember_hours = w.plots.rules.ember_stage_hours
	w.services.tick(0.1)
	assert_eq(patient.ember, 2)
	patient.ember_hours = w.plots.rules.ember_stage_hours
	w.services.tick(0.1)
	assert_true(not w.safety.people.has(patient))
	assert_eq(w.zombies.count(), 0)
	fx.destroy()


func test_destroyed_ward_releases_patient_before_turn() -> void:
	var fx := WorldFixture.new()
	var w := fx.create()
	var patient := _residents(w, 1)[0]
	var ward := w.spawn_building(w.services.cold_room, Vector2i(55, 69))
	assert_true(w.services.isolate(patient))
	w.services.tick(90)
	ward.take_damage(9999)
	assert_eq(patient.ward, null)
	patient.ember = 2
	patient.ember_hours = w.plots.rules.ember_stage_hours
	var pos := patient.sim_position()
	w.services.tick(0.1)
	assert_eq(w.zombies.count(), 1)
	assert_eq(w.zombies.position_of(0), pos)
	fx.destroy()


func test_checkpoint_waits_for_guard_then_honors_one_admission_decision() -> void:
	var fx := WorldFixture.new()
	var w := fx.create()
	var people := _residents(w, 2)
	var cell := Vector2i(57, 70)
	w.perimeter.order(Perimeter.CHECKPOINT, cell, cell)
	var gate: BarrierSegment = w.grid.barriers[cell]
	w.perimeter.add_work(gate, gate.def.build_seconds)
	w.admissions._dawn(3)
	w.admissions.waiting[gate].stage = 1
	w.admissions._tick(60.0)
	assert_true(not w.admissions.waiting[gate].checked)
	assert_true(w.perimeter.staff_wall(gate, people[0]))
	w.jobs._tick(60.0)
	w.admissions._tick(60.0)
	assert_true("no visible signs" in w.admissions.status(gate))
	var before := w.safety.people.size()
	w.admissions.decide(gate, &"isolate")
	assert_eq(w.safety.people.size(), before)
	w.admissions.decide(gate, &"accept")
	w.admissions.decide(gate, &"accept")
	assert_eq(w.safety.people.size(), before + 1)
	assert_eq(w.jobs.residents[-1].ember, 1)
	assert_true(not w.jobs.residents[-1].diagnosed)
	fx.destroy()


func test_fuel_supply_lights_and_night_attraction_stop_on_power_loss() -> void:
	var fx := WorldFixture.new()
	var w := fx.create()
	var gen := w.spawn_building(w.services.generator, Vector2i(55, 63))
	var lamp := w.spawn_building(w.services.floodlight, Vector2i(57, 67))
	Economy.add(&"fuel", 2)
	w.services.tick(1.0)
	assert_eq(Economy.get_amount(&"fuel"), 2)
	GameClock.time_of_day = w.plots.rules.night_at
	w.zombies.spawn(lamp.sim_center() + Vector2.LEFT * 100, w.horde.walker)
	w.zombies._process(0)
	w.services.tick(1.0)
	assert_eq(Economy.get_amount(&"fuel"), 1)
	assert_true(w.services._lights[lamp].visible)
	w.zombies._process(0.1)
	assert_eq(w.zombies._state[0], ZombieManager.State.INVESTIGATE)
	w.services.toggle(gen)
	assert_true(not w.services._lights[lamp].visible)
	assert_eq(w.services.supply, 0)
	w.services.tick(5.0)
	assert_eq(Economy.get_amount(&"fuel"), 1)
	fx.destroy()
