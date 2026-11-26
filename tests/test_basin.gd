extends TestCase
## A town beyond the old population limit survives a save and load on the regional map.


func test_build_and_resume_a_large_basin_district() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	var front := (load("res://scenes/main/title.tscn") as PackedScene).instantiate() as SessionFront
	tree.root.add_child(front)
	(front.get_node("%Map") as OptionButton).select(2)
	(front.get_node("%Start") as Button).pressed.emit()
	var w := front.game.world
	assert_eq(w.grid.size, Vector2i(384, 384))
	assert_eq(w.resident_capacity(), 500)
	assert_eq(w.grid.terrain_types[w.grid.index(Vector2i(153, 256))], TerrainSet.Kind.PAVEMENT)
	assert_eq(w.map_def.places.size(), 5)
	var places := front.game.get_node("Hud").get_node("%Places") as MenuButton
	assert_eq(places.get_popup().item_count, 6)
	for i in w.map_def.places.size():
		var place := w.map_def.places[i]
		places.get_popup().id_pressed.emit(i + 1)
		assert_eq(w.camera.position, w.to_view(w.grid.cell_to_world(place.extent().get_center())))
		assert_true(w.grid.get_cost(place.footprints()[0].position) <= 0)
		assert_true(
			not w.jobs.routes.between(place.origin, place.origin + Vector2i(7, 7)).is_empty()
		)
	var entry := w.roads.entrance
	var tile := float(w.grid.tile_size)
	var trunk := entry + Vector2.DOWN * 6 * tile
	assert_true(w.roads.add_road(PackedVector2Array([entry, trunk])) != null)
	assert_true(
		w.roads.add_road(PackedVector2Array([trunk, trunk + Vector2.RIGHT * 72 * tile])) != null
	)
	for col in range(1, 7):
		var cross := trunk + Vector2.RIGHT * col * 11 * tile
		assert_true(
			w.roads.add_road(PackedVector2Array([cross, cross + Vector2.DOWN * 46 * tile])) != null
		)
		for row in range(3, 44, 4):
			for side in [-1, 1]:
				var cursor := cross + Vector2(float(side) * 8.0, row * tile)
				var plot := w.plots.reserve(cursor, w.plots.rules.plot_frontage)
				if plot != null:
					w.spawn_building(w.plots.house_def, plot.house_cells[0], plot)
	var houses := w.plots.plots.size()
	assert_true(houses >= 120, "Built %d houses" % houses)
	assert_eq(w.jobs.residents.size(), houses + 1, "One starter guard and one resident per home")
	while w.safety.people.size() < w.resident_capacity():
		if w.jobs.arrive() == null:
			break
	assert_eq(w.safety.people.size(), 500)
	assert_true(w.jobs.arrive() == null)
	var saved := SaveLayout.capture(w, {"step": 0, "hidden": true})
	assert_eq(saved.get("map"), "basin")
	assert_true(front.game.restore_game(saved))
	assert_eq(front.game.world.safety.people.size(), 500)
	assert_eq(front.game.world.plots.plots.size(), houses)
	tree.root.remove_child(front)
	front.free()
	tree.paused = false
	GameClock.reset()
