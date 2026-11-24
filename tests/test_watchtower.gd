extends TestCase

const TOWER := preload("res://data/buildings/watchtower.tres")
const WALKER := preload("res://data/zombies/walker.tres")


func test_firing_needs_a_completed_tower_an_arrived_worker_ammo_and_a_live_target() -> void:
	var fx := WorldFixture.new()
	var w := fx.create()
	var site := w.try_place_building(TOWER, Vector2i(59, 68)) as DefenseTower
	assert_true(not w.jobs.sites.has(site) and w.perimeter.towers.is_empty())
	finish_construction(w)
	var point := site.sim_center() + Vector2.LEFT * w.grid.tile_size * 5
	w.zombies.spawn(point, WALKER)
	var stock := Economy.get_amount(&"ammo")
	w.zombies._process(0.1)
	assert_eq(Economy.get_amount(&"ammo"), stock, "vacant tower")
	var entrance := w.roads.entrance
	w.roads.add_road(PackedVector2Array([entrance, entrance + Vector2.DOWN * 500]))
	var plot := w.plots.reserve(entrance + Vector2(8, 150), w.plots.rules.plot_frontage)
	w.spawn_building(w.plots.house_def, plot.house_cells[0], plot)
	var person := w.jobs.residents[0]
	assert_true(w.jobs.assign(person, site))
	w.jobs._tick(0.1)
	w.zombies._process(0.1)
	assert_eq(site.shots, 0, "commuting")
	for tick in 350:
		w.jobs._tick(0.1)
	GameClock.time_of_day = w.plots.rules.dusk_at
	w.jobs._tick(0.1)
	assert_true(person.on_watch() and not person.exposed(), "defender holds post at dusk")
	Economy.add(&"ammo", -stock)
	w.zombies._process(0.1)
	assert_eq(site.shots, 0, "dry magazine")
	assert_true(Economy.pack_ammo(w.plots.rules))
	w.zombies._process(0.1)
	assert_eq(site.shots, 1)
	assert_eq(w.zombies.count(), 0)
	assert_eq(Economy.get_amount(&"ammo"), w.plots.rules.ammo_batch - TOWER.ammo_per_shot)
	w.zombies._process(1.0)
	assert_eq(site.shots, 1, "empty range consumes nothing")
	w.zombies.spawn(point, WALKER)
	w.jobs.toggle_hiring(site)
	w.zombies._process(1.0)
	assert_eq(site.shots, 1)
	site.demolish()
	assert_true(w.perimeter.towers.is_empty())
	fx.destroy()


func test_pack_ammo_debits_once_and_requires_room_for_the_whole_batch() -> void:
	var fx := WorldFixture.new()
	var w := fx.create()
	var rules := w.plots.rules
	var stock := Economy.stock.duplicate()
	assert_true(Economy.pack_ammo(rules))
	assert_eq(Economy.get_amount(&"ammo"), stock[&"ammo"] + rules.ammo_batch)
	assert_eq(Economy.get_amount(&"scrap"), stock[&"scrap"] - rules.ammo_batch_cost[&"scrap"])
	Economy.add(&"ammo", 1000)
	stock = Economy.stock.duplicate()
	assert_true(not Economy.pack_ammo(rules))
	assert_eq(Economy.stock, stock)
	Economy.add(&"ammo", -1000)
	Economy.add(&"scrap", -1000)
	assert_true(not Economy.pack_ammo(rules))
	assert_eq(Economy.get_amount(&"ammo"), 0)
	fx.destroy()
