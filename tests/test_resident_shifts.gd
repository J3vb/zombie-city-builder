extends TestCase

const GARDEN := preload("res://data/buildings/garden.tres")
const FARM := preload("res://data/buildings/farm.tres")
const WORKSHOP := preload("res://data/buildings/scrap_workshop.tres")
const STORAGE := preload("res://data/buildings/storage.tres")


func _town(w: World, count: int = 1) -> Array[Resident]:
	var p := w.roads.entrance
	var road := w.roads.add_road(PackedVector2Array([p, p + Vector2(0, 600)]))
	for i in count:
		var cursor := road.line[0] + Vector2(8, (i + 1) * 150)
		var plot := w.plots.reserve(cursor, w.plots.rules.plot_frontage)
		w.spawn_building(w.plots.house_def, plot.house_cells[0], plot)
	return w.jobs.residents


func _move(w: World, seconds: int) -> void:
	for i in seconds * 4:
		w.jobs._tick(0.25)


func test_shift_counts_only_time_on_site_and_dawn_settles_it_once() -> void:
	var fx := WorldFixture.new()
	var w := fx.create()
	var person := _town(w)[0]
	var door := person.cell
	var garden := w.spawn_building(GARDEN, Vector2i(57, 68))
	var food := Economy.get_amount(&"food")
	var water := Economy.get_amount(&"water")
	w.jobs._tick(0.1)
	assert_eq(person.job, garden)
	assert_eq(person.state, Resident.State.TO_WORK)
	assert_eq(person.shift_seconds, 0.0, "walking earns nothing")
	_move(w, 30)
	assert_eq(person.state, Resident.State.WORKING)
	assert_eq(w.grid.get_cost(person.cell) > 0, true, "works on passable ground")
	assert_eq(person.cell.distance_squared_to(garden.cell), 1, "works beside the garden")
	assert_eq(w.jobs.pending.size(), 0, "incomplete shift earns nothing")
	_move(w, 100)
	assert_eq(w.jobs.pending.get(&"food"), garden.shift_output())
	assert_eq(person.cell, door)
	assert_eq(person.state, Resident.State.SHELTERED)
	assert_eq(Economy.get_amount(&"food"), food, "completed goods wait for dawn")
	_move(w, 100)
	assert_eq(w.jobs.pending.get(&"food"), 4, "one shift per worker per day")
	garden.demolish()
	GameClock.day = 2
	EventBus.day_started.emit(2)
	assert_eq(Economy.get_amount(&"food"), food + 4 - 2, "earned food feeds the resident")
	assert_eq(Economy.get_amount(&"water"), water - 2)
	assert_eq(w.jobs.last_output.get(&"food"), 4)
	var settled := Economy.stock.duplicate()
	EventBus.day_started.emit(2)
	assert_eq(Economy.stock, settled, "no repeated ration, grant or shift payout")
	fx.destroy()


func test_pause_reassignment_and_demolition_release_one_slot() -> void:
	var fx := WorldFixture.new()
	var w := fx.create()
	var people := _town(w, 2)
	var a := w.spawn_building(GARDEN, Vector2i(56, 67))
	var b := w.spawn_building(WORKSHOP, Vector2i(55, 75))
	_move(w, 35)
	assert_true(w.jobs.worker_at(a) != w.jobs.worker_at(b), "one worker per site")
	var chosen := w.jobs.worker_at(a)
	assert_true(chosen.shift_seconds > 0.0)
	var before := chosen.shift_seconds
	GameClock.set_speed(0)
	GameClock._process(3.0)
	assert_eq(chosen.shift_seconds, before, "pause freezes work")
	GameClock.set_speed(3)
	assert_true(w.jobs.assign(chosen, b))
	assert_eq(chosen.shift_seconds, 0.0, "unfinished work does not transfer between sites")
	assert_eq(w.jobs.worker_at(a), null)
	w.jobs.toggle_hiring(a)
	_move(w, 110)
	assert_eq(w.jobs.pending.get(&"scrap"), 4)
	assert_true(not w.jobs.pending.has(&"food"))
	b.demolish()
	assert_eq(chosen.job, null)
	assert_eq(w.jobs.worker_at(b), null)
	w.jobs.toggle_hiring(a)
	_move(w, 1)
	assert_true(w.jobs.worker_at(a) in people, "other worker can take the reopened job")
	fx.destroy()


func test_blocked_site_becomes_reachable_and_dusk_sends_worker_home() -> void:
	var fx := WorldFixture.new()
	var w := fx.create()
	var person := _town(w)[0]
	var home_door := person.cell
	var site := w.spawn_building(GARDEN, Vector2i(55, 65))
	var barriers: Array[Building] = []
	for direction: Vector2i in [Vector2i.UP, Vector2i.LEFT, Vector2i.DOWN, Vector2i.RIGHT]:
		var wall := w.spawn_building(GARDEN, site.cell + direction)
		w.jobs.toggle_hiring(wall)
		barriers.append(wall)
	_move(w, 3)
	assert_eq(person.job, null, "no unreachable auto assignment")
	assert_true(not w.jobs.assign(person, site), "manual assignment also requires a route")
	assert_eq(w.jobs.pending.size(), 0)
	barriers[0].demolish()
	_move(w, 35)
	assert_eq(person.job, site, "grid change reopens the path")
	assert_eq(person.state, Resident.State.WORKING)
	GameClock.time_of_day = w.jobs.rules.dusk_at
	_move(w, 35)
	assert_eq(person.cell, home_door)
	assert_eq(person.state, Resident.State.SHELTERED)
	assert_true(w.jobs.pending.is_empty(), "unfinished shift cannot pay at night")
	var empty: Dictionary[StringName, int] = {}
	Economy.reset(empty)
	EventBus.day_started.emit(2)
	assert_true(person.hungry and person.thirsty)
	assert_eq(w.jobs.last_shortage.get(&"water"), 2)
	fx.destroy()


func test_farm_level_yield_home_loss_and_rehousing() -> void:
	var fx := WorldFixture.new()
	var w := fx.create()
	var person := _town(w)[0]
	var home := person.home
	var site := w.spawn_building(FARM, Vector2i(54, 70))
	GameClock.day = 4
	assert_true(site.upgrade())
	finish_construction(w)
	assert_true(site.upgrade())
	finish_construction(w)
	assert_eq(site.shift_output(), 12)
	_move(w, 32)
	var id := person.resident_id
	var plot := home.plot
	home.demolish()
	assert_eq(person.home, null)
	assert_eq(person.job, null)
	_move(w, 35)
	assert_true(person.at_station)
	assert_eq(w.jobs.residents.size(), 1)
	var new_home := w.spawn_building(w.plots.house_def, plot.house_cells[0], plot)
	assert_eq(person.home, new_home, "displaced resident takes the available bed")
	assert_eq(person.resident_id, id)
	assert_eq(w.jobs.residents.size(), 1)
	_move(w, 125)
	assert_eq(w.jobs.pending.get(&"food"), 12, "fully staffed greenhouse shift")
	fx.destroy()


func test_five_consecutive_dawns_and_restart_isolate_the_workforce() -> void:
	var main := (load("res://scenes/main/main.tscn") as PackedScene).instantiate() as Main
	(Engine.get_main_loop() as SceneTree).root.add_child(main)
	var w := main.world
	_town(w, 2)
	w.grower.paused = true
	w.horde.set_process(false)
	var starting_food := Economy.get_amount(&"food")
	var starting_water := Economy.get_amount(&"water")
	w.spawn_building(GARDEN, Vector2i(56, 67))
	w.spawn_building(WORKSHOP, Vector2i(55, 75))
	for day in range(2, 7):
		while GameClock.day < day:
			GameClock._advance(0.5)
		assert_eq(w.jobs.last_output.get(&"food"), 4)
		assert_eq(w.jobs.last_output.get(&"scrap"), 4)
		assert_eq(w.jobs.last_consumed.get(&"food"), 4)
		assert_true(w.jobs.last_shortage.is_empty())
	assert_eq(Economy.get_amount(&"food"), starting_food)
	assert_eq(Economy.get_amount(&"water"), starting_water - 20)
	main.new_game()
	assert_eq(main.world.jobs.residents.size(), 1)
	assert_true(main.world.jobs.pending.is_empty())
	var food := Economy.get_amount(&"food")
	GameClock.day = 2
	EventBus.day_started.emit(2)
	assert_eq(
		Economy.get_amount(&"food"), food - 2, "only the new builder and guard eat after restart"
	)
	main.free()


func test_sleep_counts_sheltered_night_time_and_recovers_next_dawn() -> void:
	var fx := WorldFixture.new()
	var w := fx.create()
	var person := _town(w)[0]
	var needed := w.jobs.rules.sleep_seconds
	person.travel(needed, w.jobs.rules.resident_speed)
	assert_eq(person.sleep_seconds, 0.0, "Daytime at home does not count")
	GameClock.time_of_day = w.jobs.rules.night_at
	person.send([], false)
	person.travel(needed, w.jobs.rules.resident_speed)
	assert_eq(person.sleep_seconds, 0.0, "A blocked route offers no shelter")
	var route: Array[Vector2i] = [person.cell]
	person.send(route, false)
	person.travel(needed / 2.0, w.jobs.rules.resident_speed)
	assert_true(person.is_sleeping())
	assert_eq(person.sleep_seconds, needed / 2.0)
	w.jobs._dawn(2)
	assert_true(person.tired)
	assert_true(is_equal_approx(person.work_pace(), 1.0 - w.jobs.rules.fatigue_pace_loss))
	person.travel(needed, w.jobs.rules.resident_speed)
	w.jobs._dawn(3)
	assert_true(not person.tired)
	assert_eq(person.work_pace(), 1.0)
	fx.destroy()
