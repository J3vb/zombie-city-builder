extends TestCase

const GARDEN := preload("res://data/buildings/garden.tres")
const WORKSHOP := preload("res://data/buildings/scrap_workshop.tres")
const FARM := preload("res://data/buildings/farm.tres")


func _work_until_started(w: World, site: Building) -> void:
	for i in 1200:
		w.construction.tick(0.1)
		if site.work_done > 0:
			return
	fail("Builder did not reach site")


func test_first_home_from_station_builder_claims_once_and_unlocks_one_bed() -> void:
	var fx := WorldFixture.new()
	var w := fx.create()
	var p := w.roads.entrance
	w.roads.add_road(PackedVector2Array([p, p + Vector2(0, 450)]))
	var plot := w.plots.reserve(p + Vector2(8, 200), w.plots.rules.plot_frontage)
	var wood := Economy.get_amount(&"wood")
	var completions: Array[Building] = []
	var record := func(building: Building) -> void: completions.append(building)
	EventBus.building_placed.connect(record)
	w.grower.step()
	var site := plot.home
	assert_eq(site.target_level, 1)
	assert_eq(w.jobs.tenant(site), null)
	assert_eq(completions.size(), 0)
	assert_eq(w.grid.building_at(site.cells[0]), site, "footprint reserved while pending")
	assert_eq(w.try_place_building(w.plots.house_def, site.cell, plot), null)
	w.construction.tick(0.1)
	assert_eq(site.work_done, 0.0, "commuting does not build")
	_work_until_started(w, site)
	var progress := site.work_done
	GameClock.set_speed(0)
	GameClock._process(1.0)
	assert_eq(site.work_done, progress)
	GameClock.set_speed(3)
	GameClock.time_of_day = w.plots.rules.dusk_at
	for i in 20:
		w.construction.tick(1.0)
	assert_eq(site.work_done, progress, "site retains its work overnight")
	GameClock.time_of_day = 0
	finish_construction(w)
	w.construction.tick(3)
	assert_eq(completions, [site])
	assert_eq(w.jobs.residents.size(), 1, "first house grants its bed exactly once")
	assert_eq(w.grid.building_at(site.cells[0]), site, "same owner after completion")
	assert_eq(Economy.get_amount(&"wood"), wood - site.def.cost[&"wood"])
	EventBus.building_placed.disconnect(record)
	fx.destroy()


func test_unreachable_site_does_not_block_queue_and_paths_reopen() -> void:
	var fx := WorldFixture.new()
	var w := fx.create()
	var cell := Vector2i(57, 68)
	var site := w.try_place_building(GARDEN, cell)
	var wall: Building
	for offset: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.UP]:
		wall = w.spawn_building(GARDEN, cell + offset)
	var second := w.try_place_building(WORKSHOP, Vector2i(69, 70))
	_work_until_started(w, second)
	assert_eq(site.work_done, 0.0)
	assert_eq(w.construction.status(site), "No walkable route to site")
	assert_true(not w.jobs.sites.has(second))
	wall.demolish()
	finish_construction(w)
	assert_true(w.jobs.sites.has(site) and w.jobs.sites.has(second))
	assert_eq(w.construction.projects.size(), 0)
	fx.destroy()


func test_cancel_or_lose_site_and_upgrade_refund_once() -> void:
	var fx := WorldFixture.new()
	var w := fx.create()
	var wood := Economy.get_amount(&"wood")
	var p := Vector2i(56, 68)
	var site := w.try_place_building(GARDEN, p)
	site.cancel_construction()
	site.cancel_construction()
	assert_eq(Economy.get_amount(&"wood"), wood)
	var destroyed := w.try_place_building(GARDEN, p)
	destroyed.take_damage(9999)
	assert_eq(Economy.get_amount(&"wood"), wood - 10, "enemy destruction grants no refund")
	var active := w.try_place_building(GARDEN, p)
	_work_until_started(w, active)
	w.construction.tick(5.0)
	var refund := active.unused_materials()
	assert_true(refund[&"wood"] > 0 and refund[&"wood"] < 10)
	var paid := Economy.get_amount(&"wood")
	active.cancel_construction()
	active.cancel_construction()
	assert_eq(Economy.get_amount(&"wood"), paid + refund[&"wood"])
	assert_eq(w.grid.building_at(p), null)
	assert_true(w.construction.projects.is_empty())
	var field := w.spawn_building(FARM, p)
	field.take_damage(40)
	GameClock.day = 2
	var stock := Economy.stock.duplicate()
	assert_true(field.upgrade())
	assert_true(not field.upgrade())
	assert_eq(field.level, 1)
	assert_eq(field.shift_output(), 6)
	field.cancel_construction()
	assert_eq(Economy.stock, stock, "unworked upgrade refunded once")
	assert_eq(w.grid.building_at(p), field, "cancel upgrade preserves farm")
	assert_true(field.upgrade())
	finish_construction(w)
	assert_eq(field.level, 2)
	assert_eq(field.health, 70)
	assert_eq(field.shift_output(), 9)
	fx.destroy()
