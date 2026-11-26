extends TestCase
## Exercise the team's real routes, off-map clocks, encounter and return through the gate.


func _town(w: World) -> Array[int]:
	var entry := w.roads.entrance
	w.roads.add_road(PackedVector2Array([entry, entry + Vector2.DOWN * 600]))
	var ids: Array[int] = []
	for row in [150, 300]:
		var plot := w.plots.reserve(entry + Vector2(8, row), w.plots.rules.plot_frontage)
		w.spawn_building(w.plots.house_def, plot.house_cells[0], plot)
		ids.append(w.jobs.residents[-1].resident_id)
	w.grower.paused = true
	return ids


func _gate(w: World) -> BarrierSegment:
	var cell := Vector2i(59, 68)
	w.perimeter.order(Perimeter.GATE, cell, cell)
	var gate: BarrierSegment = w.grid.barriers[cell]
	w.perimeter.add_work(gate, gate.def.build_seconds)
	gate.auto_close = false
	return gate


func _until(trips: Expeditions, target: Expeditions.Phase) -> void:
	for tick in 6000:
		if trips.phase == target:
			return
		trips.tick(0.25)
	fail("Team stuck at phase %s instead of %s" % [trips.phase, target])


func test_departure_requires_gate_team_and_real_stock() -> void:
	var fx := WorldFixture.new()
	var w := fx.create()
	var ids := _town(w)
	var trips := w.expeditions
	var food := Economy.get_amount(&"food")
	assert_true(not trips.launch(trips.SITES[0], ids, false).is_empty())
	_gate(w)
	var duplicates: Array[int] = [ids[0], ids[0]]
	assert_true(not trips.launch(trips.SITES[0], duplicates, false).is_empty())
	assert_eq(Economy.get_amount(&"food"), food)
	assert_eq(trips.launch(trips.SITES[0], ids, true), "")
	assert_eq(Economy.get_amount(&"food"), food - 2)
	assert_true(not trips.launch(trips.SITES[0], ids, true).is_empty())
	_until(trips, Expeditions.Phase.OUTBOUND)
	assert_true(trips.team[0].off_map and not trips.team[0].exposed())
	var time := trips.remaining
	GameClock.set_speed(0)
	GameClock._process(10.0)
	assert_eq(trips.remaining, time)
	w.jobs._dawn(2)
	assert_eq(w.jobs.last_consumed[&"food"], 1, "Only the town builder draws town rations")
	fx.destroy()


func test_choice_waits_and_return_waits_for_gate_before_recruitment_and_payout() -> void:
	var fx := WorldFixture.new()
	var w := fx.create()
	var ids := _town(w)
	var gate := _gate(w)
	var trips := w.expeditions
	assert_eq(trips.launch(trips.SITES[0], ids, false), "")
	_until(trips, Expeditions.Phase.CHOICE)
	var food := Economy.get_amount(&"food")
	trips.tick(600.0)
	assert_eq(trips.phase, Expeditions.Phase.CHOICE)
	assert_eq(Economy.get_amount(&"food"), food)
	trips.choose(true)
	var expected: int = trips.loot[&"food"]
	trips.choose(true)
	w.perimeter.set_gate(gate, false)
	_until(trips, Expeditions.Phase.ENTERING)
	trips.tick(0.25)
	assert_true(trips.route_blocked)
	assert_eq(w.safety.people.size(), 3)
	w.perimeter.set_gate(gate, true)
	_until(trips, Expeditions.Phase.IDLE)
	assert_eq(w.safety.people.size(), 4)
	assert_eq(Economy.get_amount(&"food"), food + expected)
	assert_true(w.zombies.count() > 0)
	for id in ids:
		assert_true(not w.jobs.residents[id - 1].off_map and not w.jobs.residents[id - 1].on_trip)
	assert_true("joined the town" in trips.report)
	fx.destroy()


func test_leave_choice_returns_team_without_followers_or_recruit() -> void:
	var fx := WorldFixture.new()
	var w := fx.create()
	var ids := _town(w)
	_gate(w)
	assert_eq(w.expeditions.launch(Expeditions.SITES[4], ids, false), "")
	_until(w.expeditions, Expeditions.Phase.CHOICE)
	w.expeditions.choose(false)
	_until(w.expeditions, Expeditions.Phase.IDLE)
	assert_eq(w.safety.people.size(), 3)
	assert_eq(w.zombies.count(), 0)
	assert_true(Economy.get_amount(&"medicine") > 5)
	fx.destroy()


func test_recall_before_departure_restores_unused_provisions_once() -> void:
	var fx := WorldFixture.new()
	var w := fx.create()
	var ids := _town(w)
	_gate(w)
	var stock := Economy.stock.duplicate()
	assert_eq(w.expeditions.launch(Expeditions.SITES[0], ids, true), "")
	w.expeditions.tick(0.1)
	w.expeditions.recall()
	w.expeditions.recall()
	assert_eq(Economy.stock, stock)
	assert_true(w.expeditions.team.is_empty())
	for person in w.jobs.residents:
		assert_true(not person.on_trip)
	fx.destroy()


func test_restoring_a_radio_choice_keeps_the_people_rolls_and_loot() -> void:
	var game := (load("res://scenes/main/main.tscn") as PackedScene).instantiate() as Main
	var tree := Engine.get_main_loop() as SceneTree
	tree.root.add_child(game)
	var w := game.world
	var ids := _town(w)
	_gate(w)
	assert_eq(w.expeditions.launch(Expeditions.SITES[0], ids, true), "")
	_until(w.expeditions, Expeditions.Phase.CHOICE)
	var snapshot := SaveLayout.capture(w, {"step": 4, "hidden": true})
	var state := w.expeditions.rng.state
	var people := w.safety.people.size()
	var loot := w.expeditions.loot.duplicate()
	var amount := Economy.get_amount(&"food")
	assert_true(game.restore_game(snapshot))
	var expedition := game.world.expeditions
	assert_eq(expedition.phase, Expeditions.Phase.CHOICE)
	assert_eq(expedition.rng.state, state)
	assert_eq(expedition.loot, loot)
	assert_true(expedition.team[0].off_map and expedition.team[1].on_trip)
	assert_eq(expedition.team[0].resident_id, ids[0])
	expedition.choose(true)
	var shipment: int = expedition.loot[&"food"]
	_until(expedition, Expeditions.Phase.IDLE)
	assert_eq(Economy.get_amount(&"food"), amount + shipment)
	assert_eq(game.world.safety.people.size(), people + 1)
	tree.root.remove_child(game)
	game.free()
	GameClock.reset()
