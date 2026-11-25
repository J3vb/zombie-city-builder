extends TestCase

const WALKER := preload("res://data/zombies/walker.tres")
const GARDEN := preload("res://data/buildings/garden.tres")


func _add_house(w: World, at: float) -> Building:
	var plot := w.plots.reserve(w.roads.entrance + Vector2(8, at), w.plots.rules.plot_frontage)
	return w.spawn_building(w.plots.house_def, plot.house_cells[0], plot)


func _start_shift(w: World) -> Resident:
	var entry := w.roads.entrance
	w.roads.add_road(PackedVector2Array([entry, entry + Vector2.DOWN * 700]))
	_add_house(w, 150)
	w.spawn_building(GARDEN, Vector2i(57, 68))
	for tick in 120:
		w.jobs._tick(0.25)
	return w.jobs.residents[0]


func test_four_tile_chase_retreat_shelter_and_return_to_shift() -> void:
	var fx := WorldFixture.new()
	var w := fx.create()
	var worker := _start_shift(w)
	var site := worker.job
	var point := worker.sim_position()
	var step := Vector2.RIGHT * w.grid.tile_size
	var radius := w.plots.rules.chase_radius_tiles
	w.zombies.spawn(point + step * radius + Vector2.RIGHT, WALKER)
	w.zombies._process(0.01)
	assert_eq(w.zombies._state[0], ZombieManager.State.HORDE, "outside four tiles")
	w.zombies.kill(0)
	w.zombies._process(0.0)
	w.zombies.spawn(point + step * radius, WALKER)
	w.zombies._process(0.01)
	assert_eq(w.zombies._state[0], ZombieManager.State.CHASE, "boundary counts")
	assert_true(w.zombies.position_of(0).x < point.x + step.x * radius)
	var progress := worker.shift_seconds
	w.jobs._tick(0.1)
	assert_true(worker.retreating and worker.state == Resident.State.TO_HOME)
	assert_eq(worker.shift_seconds, progress, "no shift progress while fleeing")
	assert_eq(w.jobs.worker_at(site), worker)
	w.zombies.kill(0)
	w.zombies._process(0.1)
	for tick in 200:
		w.jobs._tick(0.25)
		if worker.state == Resident.State.SHELTERED:
			break
	assert_eq(worker.state, Resident.State.SHELTERED, "retreat finishes after pursuer is gone")
	assert_true(not worker.visible)
	w.zombies.spawn(worker.sim_position(), WALKER)
	w.zombies._process(0.1)
	w.jobs._tick(0.25)
	assert_true(not worker.exposed(), "stays inside while the entrance is unsafe")
	assert_eq(worker.health, w.plots.rules.resident_health)
	w.zombies.kill(0)
	w.zombies._process(0.1)
	for tick in 480:
		w.jobs._tick(0.25)
	assert_eq(w.jobs.pending.get(&"food", 0), 4, "one shift after all-clear")
	fx.destroy()


func test_contact_cooldown_and_death_release_worker_job_and_bed_once() -> void:
	var fx := WorldFixture.new()
	var w := fx.create()
	var person := _start_shift(w)
	var home := person.home
	var job := person.job
	var previous_id := person.resident_id
	w.zombies.spawn(person.sim_position(), WALKER)
	GameClock.set_speed(0)
	w.zombies._process(1.0)
	var max_health := w.plots.rules.resident_health
	assert_eq(person.health, max_health, "pause stops hits")
	GameClock.set_speed(1)
	w.zombies._process(0.1)
	assert_eq(person.health, max_health - WALKER.civilian_damage)
	w.zombies._process(WALKER.attack_cooldown * 0.5)
	assert_eq(person.health, max_health - WALKER.civilian_damage, "still on cooldown")
	for tick in 12:
		w.zombies._process(WALKER.attack_cooldown)
		if person.is_queued_for_deletion():
			break
	assert_true(person.is_queued_for_deletion())
	assert_eq(w.safety.last_loss, person.display_name)
	assert_eq(w.jobs.worker_at(job), null)
	assert_eq(w.jobs.tenant(home), null)
	assert_eq(w.safety.people.size(), 1)
	EventBus.day_started.emit(2)
	assert_eq(w.jobs.last_consumed.get(&"food"), 1)
	var next_home := _add_house(w, 350)
	assert_true(w.jobs.tenant(next_home).resident_id > previous_id)
	fx.destroy()


func test_builder_flees_and_a_survivor_can_finish_after_builder_loss() -> void:
	var fx := WorldFixture.new()
	var w := fx.create()
	var survivor := _start_shift(w)
	var home := survivor.home
	var crew := w.construction
	var builder := crew.builder
	var order := w.try_place_building(GARDEN, Vector2i(55, 74))
	for tick in 400:
		crew.tick(0.1)
		if order.work_done > 0:
			break
	var progress := order.work_done
	assert_true(progress > 0)
	w.zombies.spawn(builder.sim_position(), WALKER)
	w.zombies._process(0.1)
	crew.tick(0.1)
	assert_true(builder.retreating)
	assert_eq(order.work_done, progress)
	assert_eq(crew.status(order), "Builder taking shelter")
	builder.take_hit(builder.health)
	assert_eq(crew.builder, survivor)
	assert_eq(w.jobs.tenant(home), survivor, "successor keeps their home")
	assert_eq(survivor.job, null)
	assert_true(not w.jobs.assign(survivor, w.jobs.sites[0]), "one person cannot work two jobs")
	w.zombies.kill(0)
	w.zombies._process(0.1)
	finish_construction(w)
	assert_true(w.jobs.sites.has(order))
	EventBus.day_started.emit(2)
	assert_eq(w.jobs.last_consumed.get(&"food"), 1, "replacement counted once")
	fx.destroy()


func test_last_resident_ends_game_and_restart_restores_the_town() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	var main := preload("res://scenes/main/main.tscn").instantiate() as Main
	tree.root.add_child(main)
	var builder := main.world.construction.builder
	builder.send([builder.cell], true)
	builder.travel(0.1, 40.0)
	builder.take_hit(builder.health)
	assert_true(GameClock.ended)
	assert_eq(main.world.safety.people.size(), 0)
	assert_true("last resident" in main.get_node("GameOver/%Message").text)
	GameClock.set_speed(3)
	assert_eq(GameClock.speed, 0)
	main.new_game()
	assert_true(not GameClock.ended)
	assert_eq(main.world.safety.people, [main.world.construction.builder])
	assert_true(main.get_node("Hud").visible)
	tree.root.remove_child(main)
	main.free()


func test_shelter_breach_exposes_occupant_and_routes_to_station() -> void:
	var fx := WorldFixture.new()
	var w := fx.create()
	var person := _start_shift(w)
	GameClock.time_of_day = w.plots.rules.dusk_at
	for tick in 200:
		w.jobs._tick(0.25)
	assert_eq(person.state, Resident.State.SHELTERED)
	var home := person.home
	home.take_damage(home.health)
	assert_true(person.exposed(), "a destroyed shelter exposes its occupant immediately")
	assert_eq(person.home, null)
	for tick in 240:
		w.jobs._tick(0.25)
	assert_eq(person.shelter, w.command_post)
	assert_true(person.at_station and not person.exposed())
	fx.destroy()


func test_nearest_exposed_civilian_takes_hit_and_a_closed_corner_blocks_contact() -> void:
	var fx := WorldFixture.new()
	var w := fx.create()
	var person := _start_shift(w)
	var other := w.construction.builder
	var cell := person.cell
	var nearby := cell + Vector2i.UP
	var path: Array[Vector2i] = [nearby]
	other.send(path, true)
	other.travel(100.0, w.plots.rules.resident_speed)
	w.zombies.spawn(other.sim_position(), WALKER)
	w.zombies._process(0.1)
	assert_eq(other.health, w.plots.rules.resident_health - WALKER.civilian_damage)
	assert_eq(person.health, w.plots.rules.resident_health)
	var corner := w.grid.cell_to_world(Vector2i(55, 75)) + Vector2.ONE * (w.grid.tile_size * 0.5)
	var before := corner - Vector2.ONE
	var after := corner + Vector2.ONE
	assert_true(w.grid.can_cross_corner(before, after))
	w.spawn_building(GARDEN, Vector2i(56, 75))
	assert_true(not w.grid.can_cross_corner(before, after))
	fx.destroy()
