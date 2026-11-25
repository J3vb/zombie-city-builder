extends TestCase
## Verify that research needs expedition loot and the campaign win needs a finished tower.


func test_blueprints_unlock_in_order_and_paid_radio_calls_once() -> void:
	var fx := WorldFixture.new()
	var w := fx.create()
	var c := w.campaign
	var tower := load("res://data/buildings/radio_tower.tres") as BuildingDef
	Economy.add(&"scrap", 50)
	assert_true(not c.research(Campaign.TECHS[0]))
	Economy.add(&"blueprints", 3)
	Economy.add(&"radio_parts", 1)
	assert_true(not c.research(Campaign.TECHS[2]))
	assert_true(w.try_place_building(tower, Vector2i(55, 64)) == null)
	for tech in Campaign.TECHS:
		assert_true(c.research(tech))
		assert_true(not c.research(tech))
	assert_eq(Economy.get_amount(&"blueprints"), 0)
	var site := w.try_place_building(tower, Vector2i(55, 64))
	assert_true(site != null)
	assert_true(not c.transmit(w))
	finish_construction(w)
	assert_true(c.transmit(w))
	assert_eq(GameClock.speed, 0)
	assert_true(not c.transmit(w))
	c.play_endless()
	assert_true(c.won and c.endless)
	assert_eq(GameClock.speed, 1)
	fx.destroy()


func test_pressure_warns_at_dusk_before_night_and_casualties_reduce_it() -> void:
	var fx := WorldFixture.new()
	var w := fx.create()
	var h := w.horde
	var b := w.plots.rules
	for i in 80:
		h.gunshot()
	h._forecast(9)
	assert_true(h.pressure > 0)
	var size := h.horde_size(9)
	h.gunshot()
	assert_eq(h.horde_size(9), size, "The forecast remains stable for the warned wave")
	h._population = w.safety.people.size() + 1
	h._dawn(10)
	h._forecast(10)
	assert_true(h.pressure < 0)
	var kinds: Dictionary[StringName,bool] = {}
	for i in 1500:
		kinds[h.choose_type(18).id] = true
	assert_eq(kinds.size(), 5)
	assert_eq(h.choose_type(1).id, &"walker")
	assert_true(h.horde_size(9) < b.horde_base + 9 * b.horde_growth)
	fx.destroy()


func test_crawlers_cross_only_barricades_and_brutes_damage_walls() -> void:
	var fx := WorldFixture.new()
	var w := fx.create()
	var cell := Vector2i(55, 64)
	w.perimeter.order(Perimeter.BARRICADE, cell, cell)
	var wall: BarrierSegment = w.grid.barriers[cell]
	w.perimeter.add_work(wall, wall.def.build_seconds)
	var motion := CrowdMotion.new()
	var crawler := load("res://data/zombies/crawler.tres") as ZombieDef
	var brute := load("res://data/zombies/brute.tres") as ZombieDef
	var point := w.grid.cell_to_world(cell)
	assert_true(motion._walkable(point, w.grid, crawler))
	assert_true(not motion._walkable(point, w.grid, brute))
	w.perimeter.remove(wall, false)
	w.perimeter.order(Perimeter.WALL, cell, cell)
	w.perimeter.add_work(w.grid.barriers[cell], Perimeter.WALL.build_seconds)
	assert_true(not motion._walkable(point, w.grid, crawler))
	assert_true(brute.wall_multiplier > 1.0)
	w.zombies.spawn(point + Vector2.RIGHT * 50, crawler)
	w.zombies.weapon_hit(0, 10, true)
	assert_eq(w.zombies._health[0], crawler.health - 7)
	fx.destroy()
