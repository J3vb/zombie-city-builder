extends TestCase

const HOUSE := preload("res://data/buildings/house.tres")
const FARM := preload("res://data/buildings/farm.tres")
const STORE := preload("res://data/buildings/storage.tres")


func _street(world: World) -> Street:
	var p := world.roads.entrance
	return world.roads.add_road(
		PackedVector2Array([p, p + Vector2(15, 150), p + Vector2(105, 285), p + Vector2(90, 420)])
	)


func _cursor(road: Street, side: float) -> Vector2:
	var i := road.line.size() / 2
	var normal := road.line[i].direction_to(road.line[i + 1]).orthogonal()
	return road.line[i] + normal * side * 10.0


func _reserve(world: World, cursor: Vector2) -> FrontagePlot:
	return world.plots.reserve(cursor, world.plots.rules.plot_frontage)


func test_two_sides_of_a_curve_keep_their_own_door() -> void:
	var fx := WorldFixture.new()
	var w := fx.create()
	var road := _street(w)
	var before := Economy.stock.duplicate()
	var left := _reserve(w, _cursor(road, 1))
	var right := _reserve(w, _cursor(road, -1))
	assert_true(left != null and right != null, "both sides of the bend accept a plot")
	assert_eq(Economy.stock, before, "reserving is free")
	assert_true(left.front.dot(right.front) < -0.95, "doors face opposite sides of the street")
	for plot in [left, right]:
		assert_true(
			plot.front.dot(plot.center.direction_to(plot.attachment)) > 0.99, "door faces street"
		)
		assert_true(
			not plot.house_cells.has(plot.door) and w.grid.get_cost(plot.door) > 0,
			"door stays walkable"
		)
		assert_eq(
			w.spawn_building(FARM, plot.door), null, "entrance is reserved against other buildings"
		)
	assert_eq(_reserve(w, _cursor(road, 1)), null, "overlap rejected")
	assert_eq(w.plots.reserve(_cursor(road, 1), 16), null, "too narrow")
	assert_eq(w.plots.plots.size(), 2, "invalid previews add no claim")
	fx.destroy()


func test_growth_keeps_its_plot_facing_health_and_cost() -> void:
	var fx := WorldFixture.new()
	var w := fx.create()
	var street := _street(w)
	var plot := _reserve(w, _cursor(street, 1))
	var before := Economy.get_amount(&"wood")
	w.grower.step()
	finish_construction(w)
	var home := plot.home
	assert_true(is_instance_valid(home), "a tent grows on the eligible plot")
	assert_eq(Economy.get_amount(&"wood"), before - 20, "pay once")
	var original := home.cells.duplicate()
	var view := home.get_node("View") as Node3D
	assert_true(
		view.basis.z.dot(Vector3(plot.front.x, 0, plot.front.y)) > 0.99,
		"model front faces the street"
	)
	home.take_damage(50)
	w.grower.step()
	finish_construction(w)
	assert_eq(home.level, 1, "day one remains a tent")
	for day in range(2, 5):
		GameClock.day = day
		EventBus.day_started.emit(day)
		w.grower.step()
		finish_construction(w)
		if day == 2:
			assert_eq(home.level, 2, "shack")
			assert_eq(home.health, 90, "shack retained half health")
	assert_eq(home.level, 3, "brick house on day four")
	assert_eq(home.health, 150, "brick house retained half health")
	assert_eq(original, home.cells, "same occupied cells through upgrades")
	assert_eq(Economy.get_amount(&"wood"), before - 20 - 30 - 40, "each stage paid once")
	assert_eq(w.grid.get_cost(plot.door), 1, "walking access after upgrades")
	fx.destroy()


func test_removing_home_plot_and_branch_releases_only_their_claims() -> void:
	var fx := WorldFixture.new()
	var w := fx.create()
	var p := w.roads.entrance
	var trunk := w.roads.add_road(PackedVector2Array([p, p + Vector2(0, 400)]))
	var branch := w.roads.add_road(PackedVector2Array([p + Vector2(0, 215), p + Vector2(440, 215)]))
	var plot := _reserve(w, _cursor(branch, 1))
	w.grower.step()
	finish_construction(w)
	assert_true(not w.roads.remove_road(branch.id), "occupied frontage protects its street")
	assert_true(not w.roads.remove_road(trunk.id), "cannot disconnect an occupied side street")
	assert_true(not w.plots.remove_plot(plot.id), "cannot release an occupied plot")
	var before := Economy.get_amount(&"wood")
	var home := plot.home
	home.demolish()
	home.demolish()
	assert_eq(Economy.get_amount(&"wood"), before + 10, "one refund")
	assert_true(w.grid.parcel_cells.has(plot.door), "demolition preserves parcel")
	assert_true(w.plots.remove_plot(plot.id), "release empty lot")
	assert_true(w.roads.remove_road(branch.id), "remove cleared street")
	assert_true(w.grid.parcel_cells.is_empty(), "all its reservations released")
	assert_true(w.grid.is_free(home.cells), "house land can be reused")
	fx.destroy()


func test_farm_and_storage_grow_from_painted_zones() -> void:
	var fx := WorldFixture.new()
	var w := fx.create()
	var farm := Rect2i(20, 20, 3, 3)
	var store := Rect2i(30, 20, 2, 2)
	w.grower.paint(farm, FARM)
	w.grower.paint(store, STORE)
	w.grower.paused = true
	w.grower.step()
	finish_construction(w)
	assert_eq(w.grid.building_at(farm.position), null, "growth pause")
	w.grower.paused = false
	w.grower.step()
	finish_construction(w)
	w.grower.step()
	finish_construction(w)
	assert_eq(w.grid.building_at(farm.position).def, FARM, "whole farm zone grew")
	assert_eq(w.grid.building_at(store.position).def, STORE, "storage zone grew")
	w.grower.paint(farm, null)
	assert_eq(w.grid.building_at(farm.position).def, FARM, "erasing zone leaves building standing")
	fx.destroy()


func test_disconnected_street_and_unaffordable_home_cannot_grow() -> void:
	var fx := WorldFixture.new()
	var w := fx.create()
	var p := w.roads.entrance + Vector2(400, 0)
	var isolated := w.roads.add_road(PackedVector2Array([p, p + Vector2(0, 300)]))
	assert_eq(_reserve(w, _cursor(isolated, 1)), null, "road requires a connection")
	var road := _street(w)
	var plot := _reserve(w, _cursor(road, -1))
	var empty: Dictionary[StringName,int] = {&"wood": 0}
	Economy.reset(empty)
	w.grower.step()
	finish_construction(w)
	assert_eq(plot.home, null, "unaffordable plot stays vacant")
	Economy.add(&"wood", 20)
	GameClock.time_of_day = 0.8
	w.grower.step()
	finish_construction(w)
	assert_eq(plot.home, null, "no growth at night")
	GameClock.time_of_day = 0.1
	w.grower.step()
	finish_construction(w)
	assert_true(is_instance_valid(plot.home), "eligible plot grows after funds and daylight")
	fx.destroy()


func _mouse(tool: PlotTool, screen: Vector2) -> void:
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	click.position = screen
	tool._unhandled_input(click)


func test_mouse_tools_reserve_demolish_release_and_remove() -> void:
	var fx := WorldFixture.new()
	var w := fx.create()
	var street := _street(w)
	var cursor := _cursor(street, 1)
	w.camera.position = w.to_view(cursor)
	w.camera.lens.force_update_transform()
	w.plot_tool.select(PlotTool.Mode.HOME)
	_mouse(w.plot_tool, w.camera.lens.unproject_position(w.to_view(cursor)))
	assert_eq(w.plots.plots.size(), 1, "picked frontage in 3D")
	w.grower.step()
	finish_construction(w)
	var plot: FrontagePlot = w.plots.plots.values()[0]
	var roof := w.to_view(plot.center) + Vector3.UP * plot.home.def.levels[0].height
	w.camera.rotation.y = 0.8
	w.camera.lens.force_update_transform()
	w.plot_tool.select(PlotTool.Mode.DEMOLISH)
	_mouse(w.plot_tool, w.camera.lens.unproject_position(roof))
	assert_eq(plot.home, null, "click the visible roof to demolish")
	w.plot_tool.select(PlotTool.Mode.REMOVE_PLOT)
	_mouse(w.plot_tool, w.camera.lens.unproject_position(w.to_view(plot.center)))
	assert_true(w.plots.plots.is_empty(), "release confirmed parcel")
	w.plot_tool.select(PlotTool.Mode.REMOVE_ROAD)
	_mouse(w.plot_tool, w.camera.lens.unproject_position(w.to_view(plot.attachment)))
	assert_true(w.roads.roads.is_empty(), "remove street via its surface")
	fx.destroy()


func test_frontage_rejects_a_second_road_and_water_under_the_house() -> void:
	var fx := WorldFixture.new()
	var w := fx.create()
	var start := w.roads.entrance
	var road := w.roads.add_road(PackedVector2Array([start, start + Vector2(0, 400)]))
	var second := start + Vector2(120, 0)
	w.roads.add_road(PackedVector2Array([second, second + Vector2(0, 400)]))
	var cursor := road.line[road.line.size() / 2] + Vector2.RIGHT * 8
	assert_eq(_reserve(w, cursor), null, "house cannot cross the parallel street")
	assert_eq(
		_reserve(w, road.line[-1] + Vector2.RIGHT * 8), null, "frontage cannot extend past the end"
	)
	var t := float(w.grid.tile_size)
	var coastal := w.roads.add_road(
		PackedVector2Array(
			[
				start,
				Vector2(48, 82) * t,
				Vector2(40, 87.5) * t,
				Vector2(20, 87.5) * t,
				Vector2(12, 87.5) * t
			]
		)
	)
	assert_true(coastal != null, "shore road stays on dry ground")
	var hit := coastal.nearest(Vector2(30, 87.5) * t)
	var toward_water: Vector2 = hit.point + Vector2.DOWN * 8
	assert_eq(_reserve(w, toward_water), null, "water under the house rejects the whole plot")
	assert_true(w.plots.plots.is_empty(), "no partial reservations")
	fx.destroy()


func test_inspect_rotated_brick_house_on_a_bend() -> void:
	var fx := WorldFixture.new()
	var w := fx.create()
	var road := _street(w)
	var plot := _reserve(w, _cursor(road, 1))
	w.grower.step()
	finish_construction(w)
	GameClock.day = 4
	plot.home.upgrade()
	finish_construction(w)
	plot.home.upgrade()
	finish_construction(w)
	w.camera.position = w.to_view(plot.center)
	w.camera.rotation.y = 0.9
	w.camera.pitch_deg = 30
	w.camera._apply()
	w.camera.lens.force_update_transform()
	var roof := w.to_view(plot.center) + Vector3.UP * HOUSE.levels[2].height
	_mouse(w.plot_tool, w.camera.lens.unproject_position(roof))
	assert_eq(
		w.plot_tool.selected_building, plot.home, "select level-three roof on rotated frontage"
	)
	plot.home.take_damage(999)
	assert_eq(w.plot_tool.selected_building, null, "damage destroys the selected home")
	fx.destroy()
