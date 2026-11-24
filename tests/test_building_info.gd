extends TestCase

const FARM := preload("res://data/buildings/farm.tres")
const STORAGE := preload("res://data/buildings/storage.tres")
const MAIN := preload("res://scenes/main/main.tscn")


func test_upgrade_explains_day_light_and_all_shortages_before_spending() -> void:
	var fx := WorldFixture.new()
	var w := fx.create()
	var store := w.spawn_building(STORAGE, Vector2i(20, 20))
	assert_eq(store.upgrade_blocker(), "Unlocks on day 2")
	GameClock.day = 2
	GameClock.time_of_day = 0.85
	assert_eq(store.upgrade_blocker(), "Waits for daylight")
	assert_true(not store.upgrade(), "night cannot spend")
	GameClock.time_of_day = 0.0
	assert_eq(store.upgrade_blocker(), "")
	store.take_damage(60)
	var cells := store.cells.duplicate()
	var before := Economy.get_amount(&"wood")
	assert_true(store.upgrade(), "day 2 shed")
	assert_eq(store.health, 100)
	assert_eq(Economy.get_amount(&"wood"), before - 30)
	GameClock.day = 4
	var partial: Dictionary[StringName, int] = {&"wood": 17, &"scrap": 34}
	Economy.reset(partial)
	assert_eq(store.upgrade_blocker(), "Needs 13 wood, 6 scrap")
	assert_true(not store.upgrade(), "shortages block the actual upgrade")
	assert_eq(Economy.stock, partial)
	Economy.add(&"wood", 13)
	Economy.add(&"scrap", 6)
	assert_true(store.upgrade(), "day 4 warehouse")
	assert_eq(store.health, 175)
	assert_eq(store.cells, cells)
	assert_eq(store.upgrade_blocker(), "Max level")
	assert_true(not store.upgrade())
	assert_eq(Economy.get_amount(&"wood") + Economy.get_amount(&"scrap"), 0)
	fx.destroy()


func test_mixed_upgrades_take_nearest_affordable_and_share_daily_limit() -> void:
	var fx := WorldFixture.new()
	var w := fx.create()
	var farm := w.spawn_building(FARM, Vector2i(48, 48))
	var store := w.spawn_building(STORAGE, Vector2i(20, 20))
	var outer := w.spawn_building(FARM, Vector2i(10, 10))
	farm.take_damage(40)
	GameClock.day = 4
	w.grower.step()
	assert_eq(farm.level, 2, "nearest to Station 4")
	assert_eq(farm.health, 70)
	var low: Dictionary[StringName, int] = {&"wood": 30}
	Economy.reset(low)
	w.grower.step()
	assert_eq(store.level, 2, "nearest affordable stage when greenhouse lacks scrap")
	assert_eq(outer.level, 1)
	Economy.add(&"wood", 100)
	Economy.add(&"scrap", 100)
	assert_eq(w.grower.upgrade_status(outer), "Daily limit reached")
	w.grower.step()
	assert_eq(farm.level, 2, "daily upgrade cap shared by all types")
	EventBus.day_started.emit(5)
	w.grower.paused = true
	assert_eq(w.grower.upgrade_status(farm), "Town growth is paused")
	w.grower.paused = false
	GameClock.set_speed(0)
	assert_eq(w.grower.upgrade_status(farm), "Clock is paused")
	GameClock.set_speed(1)
	assert_eq(w.grower.upgrade_status(farm), "Waiting for its turn")
	w.grower.step()
	assert_eq(farm.level, 3)
	assert_eq(farm.health, 110)
	assert_eq(farm.def.levels[farm.level - 1].title, "Greenhouse")
	fx.destroy()


func _click(world: World, point: Vector3) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	event.position = world.camera.lens.unproject_position(point)
	world.plot_tool._unhandled_input(event)


func test_roof_selection_with_a_building_behind_and_all_clear_actions() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	var main := MAIN.instantiate() as Main
	tree.root.add_child(main)
	var w := main.world
	var front := w.spawn_building(STORAGE, Vector2i(35, 35))
	var behind := w.spawn_building(STORAGE, Vector2i(35, 32))
	GameClock.day = 4
	front.upgrade()
	front.upgrade()
	var center := w.to_view(front.sim_center())
	w.camera.rotation.y = 0
	w.camera.position = center
	w.camera.pitch_deg = 30
	w.camera._apply()
	w.camera.lens.force_update_transform()
	var roof := center + Vector3.UP * front.def.levels[2].height
	var ground: Vector3 = w.camera.ground_at(w.camera.lens.unproject_position(roof))
	assert_eq(
		w.grid.building_at(w.grid.world_to_cell(w.to_sim(ground))),
		behind,
		"ground-only picking would hit the rear building"
	)
	_click(w, roof)
	var hud := main.get_node("Hud") as Hud
	var panel := hud.get_node("BuildingInfo") as PanelContainer
	hud._process(0)
	assert_eq(w.plot_tool.selected_building, front, "pick closest roof at 30 degrees")
	assert_true(panel.visible)
	assert_eq(panel.get_node("%Title").text, "Warehouse")
	assert_eq(panel.get_node("%Status").text, "Fully upgraded")
	front.take_damage(50)
	hud._process(0)
	assert_eq(panel.get_node("%Health").text, "Health   300 / 350")
	_click(w, center + Vector3(35, 0, 0))
	assert_eq(w.plot_tool.selected_building, null, "empty ground")
	_click(w, roof)
	var cancel := InputEventAction.new()
	cancel.action = &"cancel"
	cancel.pressed = true
	w.plot_tool._unhandled_input(cancel)
	assert_eq(w.plot_tool.selected_building, null, "cancel")
	_click(w, roof)
	w.road_tool.select()
	assert_eq(w.plot_tool.selected_building, null, "street tool clears")
	_click(w, roof)
	assert_eq(w.plot_tool.selected_building, null, "road input remains with its tool")
	w.road_tool.clear()
	_click(w, roof)
	w.plot_tool.select(PlotTool.Mode.HOME)
	assert_eq(w.plot_tool.selected_building, null, "home plot tool clears")
	w.plot_tool.clear()
	_click(w, roof)
	w.build_tool.select(FARM)
	assert_eq(w.plot_tool.selected_building, null, "placement tool clears")
	w.build_tool.clear()
	_click(w, roof)
	front.demolish()
	assert_eq(w.plot_tool.selected_building, null, "demolition clears immediately")
	w.camera.position = w.to_view(w.command_post.sim_center())
	w.camera.lens.force_update_transform()
	_click(w, w.to_view(w.command_post.sim_center()) + Vector3.UP * 3)
	hud._process(0)
	assert_true(panel.visible and not panel.get_node("%Next").visible, "Station 4 has one stage")
	main.new_game()
	assert_true(not panel.visible, "restart closes inspection")
	main.free()
