extends TestCase

const TRIAL := preload("res://scenes/tests/supply_town.tscn")
const STORAGE := preload("res://data/buildings/storage.tres")
const GARDEN := preload("res://data/buildings/garden.tres")
const WELL := preload("res://data/buildings/well.tres")
const LUMBER := preload("res://data/buildings/lumber_yard.tres")


func _next_dawn() -> void:
	var day := GameClock.day
	while GameClock.day == day:
		GameClock._advance(0.5)


func test_ten_people_five_days_then_water_shortage_and_recovery() -> void:
	var trial := TRIAL.instantiate()
	var tree := Engine.get_main_loop() as SceneTree
	tree.root.add_child(trial)
	var w: World = trial.get_node("Main").world
	assert_eq(w.jobs.residents.size() + 1, 10)
	assert_eq(w.jobs.sites.size(), 6, "Five production sites and the starter watchtower")
	for day in range(2, 7):
		_next_dawn()
		assert_eq(w.jobs.last_dawn, day)
		for item: StringName in [&"food", &"water"]:
			assert_eq(w.jobs.last_output.get(item, 0), 12, "%s produced on day %d" % [item, day])
			assert_eq(w.jobs.last_consumed.get(item, 0), 10, "%s used on day %d" % [item, day])
		assert_eq(w.jobs.last_output.get(&"wood", 0), 16)
		assert_eq(w.jobs.last_output.get(&"scrap", 0), 4)
		assert_true(w.jobs.last_shortage.is_empty())
	assert_eq(Economy.get_amount(&"food"), 20)
	assert_eq(Economy.get_amount(&"water"), 10)
	assert_eq(Economy.get_amount(&"wood"), 80)
	assert_eq(Economy.get_amount(&"scrap"), 20)
	var well := w.grid.building_at(Vector2i(56, 76))
	w.jobs.toggle_hiring(well)
	_next_dawn()
	assert_eq(Economy.get_amount(&"water"), 0)
	assert_true(w.jobs.last_shortage.is_empty(), "last reserve covers one dawn")
	_next_dawn()
	assert_eq(w.jobs.last_shortage.get(&"water", 0), 10)
	assert_eq(w.jobs.last_overflow.get(&"wood", 0), 12)
	var hud: Hud = trial.get_node("Main/Hud")
	hud._process(0.0)
	assert_true("Short 10 water" in hud.get_node("%DawnReport").text)
	assert_true(is_equal_approx(w.construction.builder.work_pace(), 0.9))
	w.jobs.toggle_hiring(well)
	_next_dawn()
	assert_eq(Economy.get_amount(&"water"), 2)
	assert_true(w.jobs.last_shortage.is_empty())
	assert_eq(w.construction.builder.work_pace(), 1.0)
	assert_eq(w.jobs.worker_at(well).work_pace(), 1.0)
	tree.root.remove_child(trial)
	trial.free()


func test_completed_storage_and_upgrades_change_capacity_without_losing_stock() -> void:
	var fx := WorldFixture.new()
	var w := fx.create()
	assert_eq(Economy.capacity, 100)
	var storage := w.try_place_building(STORAGE, Vector2i(55, 70))
	assert_eq(Economy.capacity, 100)
	finish_construction(w)
	assert_eq(Economy.capacity, 140)
	GameClock.day = 2
	assert_true(storage.upgrade())
	assert_eq(Economy.capacity, 140)
	storage.cancel_construction()
	assert_eq(Economy.capacity, 140)
	assert_true(storage.upgrade())
	finish_construction(w)
	assert_eq(Economy.capacity, 180)
	GameClock.day = 4
	Economy.add(&"scrap", 40)
	assert_true(storage.upgrade())
	finish_construction(w)
	assert_eq(Economy.capacity, 240)
	Economy.add(&"wood", 1000)
	var site := w.try_place_building(GARDEN, Vector2i(55, 75))
	assert_eq(Economy.add(&"wood", 15), 10, "only ten slots remain")
	storage.take_damage(9999)
	assert_eq(Economy.capacity, 100)
	assert_eq(Economy.get_amount(&"wood"), 240)
	site.cancel_construction()
	site.cancel_construction()
	assert_eq(Economy.get_amount(&"wood"), 250, "untouched order returns exactly ten wood")
	assert_eq(Economy.add(&"wood", 5), 0)
	assert_eq(Economy.add(&"wood", -151), -151)
	assert_eq(Economy.add(&"wood", 20), 1)
	fx.destroy()


func test_order_well_and_lumber_yard_and_apply_shortage_floor() -> void:
	var fx := WorldFixture.new()
	var w := fx.create()
	var well := w.try_place_building(WELL, Vector2i(56, 73))
	var yard := w.try_place_building(LUMBER, Vector2i(70, 73))
	assert_true(well != null and yard != null)
	assert_true(w.jobs.sites.is_empty())
	finish_construction(w)
	assert_eq(well.shift_output(), 12)
	assert_eq(yard.shift_output(), 16)
	assert_true(w.jobs.sites.has(well) and w.jobs.sites.has(yard))
	var builder := w.construction.builder
	for day in 5:
		builder.update_ration(true, true)
	assert_eq(builder.work_pace(), 0.5)
	builder.update_ration(false, false)
	assert_eq(builder.work_pace(), 1.0)
	fx.destroy()
