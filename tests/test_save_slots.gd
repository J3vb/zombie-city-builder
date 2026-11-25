extends TestCase
## Round-trip an actual settlement and ensure malformed slots preserve the active town.

const GAME := preload("res://scenes/main/main.tscn")
const TEMP := "user://save-tests"


func test_resume_a_live_street_gate_builder_wave_and_rng() -> void:
	var game := GAME.instantiate() as Main
	var tree := Engine.get_main_loop() as SceneTree
	tree.root.add_child(game)
	var w := game.world
	var entry := w.roads.entrance
	w.roads.add_road(PackedVector2Array([entry, entry + Vector2.DOWN * 350]))
	var p := w.plots.reserve(entry + Vector2(8, 180), w.plots.rules.plot_frontage)
	assert_true(p != null)
	var house := w.spawn_building(w.plots.house_def, p.house_cells[0], p)
	var site := w.try_place_building(load("res://data/buildings/garden.tres"), Vector2i(58, 61))
	assert_true(house != null and site != null)
	var cell := Vector2i(60, 70)
	assert_true(w.perimeter.order(Perimeter.GATE, cell, cell))
	var gate: BarrierSegment = w.grid.barriers[cell]
	w.perimeter.add_work(gate, gate.def.build_seconds)
	w.perimeter.set_gate(gate, false)
	w.jobs.residents[0].hungry = true
	w.zombies.spawn(entry + Vector2(800, 400), w.horde.walker)
	w.horde.queue_spawn(13)
	var expect_rng := w.horde.rng.state
	GameClock.day = 9
	GameClock.time_of_day = 0.67
	GameClock.set_speed(2)
	var before := Economy.get_amount(&"wood")
	var old_dir := SaveManager.directory
	SaveManager.directory = TEMP
	assert_true(SaveManager.write_slot(game, 1), SaveManager.message)
	var data := SaveManager.read_slot(1)
	assert_true(not data.is_empty(), SaveManager.message)
	if not data.is_empty():
		assert_true(game.restore_game(data), "Could not restore the town")
	var resumed := game.world
	assert_eq(GameClock.day, 9)
	assert_eq(GameClock.speed, 2)
	assert_eq(Economy.get_amount(&"wood"), before)
	assert_eq(resumed.horde.rng.state, expect_rng)
	assert_eq(resumed.zombies.count(), 1)
	assert_eq(resumed.horde.queued, 13)
	assert_true(resumed != w)
	assert_true(resumed.jobs.residents[0].hungry)
	assert_eq(resumed.plots.plots.size(), 1)
	assert_true(not resumed.grid.barriers[cell].opened)
	assert_true(resumed.grid.building_at(Vector2i(58, 61)).target_level == 1)
	assert_true(SaveManager.write_slot(game, 1))
	var file := FileAccess.open(TEMP + "/slot_1.json", FileAccess.WRITE)
	file.store_string("broken")
	file.close()
	assert_true(not SaveManager.read_slot(1).is_empty())
	data["clock"] = {}
	assert_true(not game.restore_game(data))
	assert_true(game.world == resumed and GameClock.day == 9)
	SaveManager.directory = old_dir
	for suffix in ["", ".bak", ".tmp"]:
		if FileAccess.file_exists(TEMP + "/slot_1.json" + suffix):
			DirAccess.remove_absolute(TEMP + "/slot_1.json" + suffix)
	tree.root.remove_child(game)
	game.free()
	GameClock.reset()


func test_dawn_autosave_and_manual_slot_remain_independent() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	var game := GAME.instantiate() as Main
	tree.root.add_child(game)
	var old_dir := SaveManager.directory
	SaveManager.directory = TEMP
	SaveManager.bind(game)
	assert_true(SaveManager.write_slot(game, 2))
	GameClock.time_of_day = 0.99999
	GameClock._advance(0.1)
	await tree.process_frame
	await tree.process_frame
	var codec := SaveValues.new()
	var auto := SaveManager.read_slot(0)
	var manual := SaveManager.read_slot(2)
	assert_true(not auto.is_empty() and not manual.is_empty())
	if not auto.is_empty() and not manual.is_empty():
		assert_eq(codec.decode(auto.clock.day), 2)
		assert_eq(codec.decode(manual.clock.day), 1)
	var f := FileAccess.open(TEMP + "/slot_3.json", FileAccess.WRITE)
	f.store_string('{"version": 77}')
	f.close()
	assert_true(SaveManager.read_slot(3).is_empty())
	assert_true(SaveManager.message.contains("unsupported"))
	for slot in [0, 2, 3]:
		for suffix in ["", ".bak", ".tmp"]:
			var path: String = TEMP + "/slot_%d.json" % slot + suffix
			if FileAccess.file_exists(path):
				DirAccess.remove_absolute(path)
	SaveManager.directory = old_dir
	tree.root.remove_child(game)
	game.free()
	GameClock.reset()
