extends TestCase

const WALKER := preload("res://data/zombies/walker.tres")


func _finish(w: World) -> void:
	for tick in 1600:
		if w.perimeter.orders.is_empty():
			return
		w.construction.tick(0.25)
	fail("Perimeter crew did not finish")


func test_drag_reserves_and_pays_once_or_rejects_the_whole_line() -> void:
	var fx := WorldFixture.new()
	var w := fx.create()
	var a := Vector2i(52, 66)
	var b := a + Vector2i(3, 1)
	var wood := Economy.get_amount(&"wood")
	assert_true(w.perimeter.order(Perimeter.BARRICADE, a, b))
	assert_eq(w.perimeter.orders.size(), 4, "drag snaps to the dominant axis")
	assert_eq(Economy.get_amount(&"wood"), wood - 8)
	assert_true(not w.grid.is_free([a]), "unfinished claim")
	assert_true(w.grid.get_cost(a) > 0, "stakes are passable before completion")
	assert_true(not w.perimeter.order(Perimeter.WALL, a - Vector2i.RIGHT, a))
	assert_true(not w.grid.barriers.has(a - Vector2i.RIGHT))
	assert_eq(Economy.get_amount(&"wood"), wood - 8)
	var canceled: BarrierSegment = w.grid.barriers[a]
	w.perimeter.add_work(canceled, 1)
	w.perimeter.remove(canceled, true)
	w.perimeter.remove(canceled, true)
	assert_eq(Economy.get_amount(&"wood"), wood - 7, "one unused wood returned")
	_finish(w)
	assert_eq(w.grid.get_cost(a + Vector2i.RIGHT), Grid.BLOCKED)
	var cell := Vector2i(42, 72)
	Economy.add(&"wood", -1000)
	assert_true(not w.perimeter.order(Perimeter.WALL, cell, cell + Vector2i.RIGHT))
	assert_true(not w.grid.barriers.has(cell))
	fx.destroy()


func test_gate_crossing_preserves_the_road_and_waits_for_occupants() -> void:
	var fx := WorldFixture.new()
	var w := fx.create()
	var cell := Vector2i(52, 66)
	w.grid.mark_road([cell], 1)
	assert_true(not w.perimeter.order(Perimeter.BARRICADE, cell, cell))
	assert_true(w.perimeter.order(Perimeter.GATE, cell, cell))
	_finish(w)
	var gate: BarrierSegment = w.grid.barriers[cell]
	assert_true(gate.opened)
	assert_eq(w.grid.get_cost(cell), 1)
	gate.auto_close = false
	EventBus.dusk_started.emit(1)
	assert_true(gate.opened)
	gate.auto_close = true
	w.zombies.spawn(w.grid.cell_to_world(cell), WALKER)
	EventBus.dusk_started.emit(1)
	assert_true(gate.close_pending and gate.opened)
	w.perimeter.set_gate(gate, true)
	assert_true(not gate.close_pending)
	w.perimeter.set_gate(gate, false)
	w.zombies.kill(0)
	w.perimeter._tick(0.1)
	assert_true(gate.blocks() and not gate.close_pending)
	assert_eq(w.grid.get_cost(cell), Grid.BLOCKED)
	w.perimeter.set_gate(gate, true)
	assert_eq(w.grid.get_cost(cell), 1)
	assert_true(not w.grid.is_free([cell]), "open gate still owns its tile")
	w.perimeter.remove(gate, true)
	assert_true(w.grid.road_cells.has(cell))
	assert_eq(w.grid.get_cost(cell), 1)
	fx.destroy()


func _route_crossing(w: World, start: Vector2i, goal: Vector2i) -> Vector2i:
	w.flow_field.build(
		w.grid.horde_costs(), w.grid.size, PackedInt32Array([w.grid.index(goal)]), w.grid.cost
	)
	var cell := start
	for step in 40:
		if w.grid.barriers.has(cell):
			return cell
		var dir := w.flow_field.direction_at(cell)
		cell += Vector2i(roundi(dir.x), roundi(dir.y))
	return BuildTool.NO_CELL


func test_open_gate_then_cheapest_breach_and_actual_destruction() -> void:
	var fx := WorldFixture.new()
	var w := fx.create()
	var goal := Vector2i(50, 65)
	var gate_cell := goal + Vector2i.LEFT * 2
	var weak := goal + Vector2i.RIGHT * 2
	for x in range(-2, 3):
		for y in range(-2, 3):
			if maxi(absi(x), absi(y)) != 2:
				continue
			var cell := goal + Vector2i(x, y)
			var def := Perimeter.WALL
			if cell == gate_cell:
				def = Perimeter.GATE
			elif cell == weak:
				def = Perimeter.BARRICADE
			assert_true(w.perimeter.order(def, cell, cell))
			w.perimeter.add_work(w.grid.barriers[cell], def.build_seconds)
	var start := weak + Vector2i.RIGHT
	assert_eq(_route_crossing(w, start, goal), gate_cell, "open passage beats breaking timber")
	w.perimeter.set_gate(w.grid.barriers[gate_cell], false)
	assert_eq(_route_crossing(w, start, goal), weak, "closed gate sends Walker to cheaper wall")
	w.zombies.spawn(w.grid.cell_to_world(start), WALKER)
	for tick in 300:
		w.zombies._process(0.1)
		if not w.grid.barriers.has(weak):
			break
	assert_true(not w.grid.barriers.has(weak), "Walker opened a breach")
	assert_true(w.grid.get_cost(weak) > 0)
	assert_true(w.grid.barriers[gate_cell].blocks())
	fx.destroy()
