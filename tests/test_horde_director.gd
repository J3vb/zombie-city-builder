extends TestCase

const BALANCE := preload("res://data/balance.tres")


func test_horde_size_formula() -> void:
	var fx := WorldFixture.new()
	var world := fx.create()
	var b: BalanceDef = BALANCE
	assert_eq(world.horde.horde_size(3), b.horde_base + 3 * b.horde_growth, "day 3")
	fx.destroy()


func test_night_queues_horde() -> void:
	var fx := WorldFixture.new()
	var world := fx.create()
	EventBus.night_started.emit(2)
	assert_eq(world.horde.queued, world.horde.horde_size(2), "queued")
	fx.destroy()


func test_spawn_cells_are_passable_and_inside_border() -> void:
	var fx := WorldFixture.new()
	var world := fx.create()
	var b := world.map_def.border_width
	var cells := world.horde.spawn_cells()
	assert_true(cells.size() > 100, "has spawn cells")
	for cell in cells:
		if world.grid.get_cost(cell) <= 0:
			fail("blocked spawn cell %s" % cell)
			break
		if cell.x < b or cell.y < b:
			fail("spawn cell in border %s" % cell)
			break
	fx.destroy()


func test_spawns_in_batches() -> void:
	var fx := WorldFixture.new()
	var world := fx.create()
	var b: BalanceDef = BALANCE
	world.horde.queue_spawn(b.spawns_per_frame + 5)
	world.horde._process(0.016)
	assert_eq(world.zombies.count(), b.spawns_per_frame, "first batch")
	world.horde._process(0.016)
	assert_eq(world.zombies.count(), b.spawns_per_frame + 5, "rest")
	fx.destroy()


func test_major_forecast_matches_spawn_edge_and_expires_at_dawn() -> void:
	var fx := WorldFixture.new()
	var w := fx.create()
	GameClock.day = 3
	w.horde.rng.seed = 4
	EventBus.dusk_started.emit(3)
	var side := w.horde.approach
	assert_true(not w.horde.warning().is_empty())
	assert_eq(w.horde.queued, 0, "Dusk gives time to prepare")
	EventBus.night_started.emit(3)
	assert_eq(w.horde.approach, side)
	assert_true(w.horde.horde_size(3) > w.horde.horde_size(4))
	var b := w.map_def.border_width
	for i in 64:
		var cell := w.grid.world_to_cell(w.horde.random_spawn_point())
		var edges := [
			cell.y == b,
			cell.x == w.grid.size.x - 1 - b,
			cell.y == w.grid.size.y - 1 - b,
			cell.x == b
		]
		assert_true(edges[side], "Spawned on the warned edge")
	GameClock.day = 4
	assert_true(w.horde.warning().is_empty())
	EventBus.dusk_started.emit(4)
	assert_eq(w.horde.approach, -1)
	fx.destroy()
