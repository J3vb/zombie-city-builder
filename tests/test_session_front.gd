extends TestCase
## Exercise title, actual map selection, pause, defeat and return to the title.


func test_mill_crossing_and_pause_keep_the_same_town() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	var front := (load("res://scenes/main/title.tscn") as PackedScene).instantiate() as SessionFront
	tree.root.add_child(front)
	assert_true(tree.paused and front.game == null)
	var music_volume := Settings.volume("Music")
	assert_true(is_equal_approx(AudioManager._music.volume_linear, 0.85))
	(front.get_node("%Map") as OptionButton).select(1)
	(front.get_node("%Start") as Button).pressed.emit()
	var w := front.game.world
	assert_true(is_equal_approx(AudioManager._music.volume_linear, 1.0))
	assert_eq(w.map_def.display_name, "Mill Crossing")
	assert_eq(w.grid.size, Vector2i(144, 112))
	var terrain := StarterMap.generate(w.map_def)
	assert_eq(terrain[60 * 144 + 70], TerrainSet.Kind.WATER)
	assert_eq(terrain[36 * 144 + 70], TerrainSet.Kind.GROUND)
	GameClock.set_speed(3)
	front.pause_game()
	assert_true(tree.paused and not w.can_process())
	assert_true(is_equal_approx(AudioManager._music.volume_linear, 1.0))
	front.resume_game()
	assert_true(not tree.paused and w.can_process())
	assert_eq(GameClock.speed, 3)
	assert_true(w == front.game.world)
	EventBus.game_over.emit(3)
	assert_true(GameClock.ended)
	(front.game.get_node("GameOver/Center/Panel/Box/Title") as Button).pressed.emit()
	assert_true(tree.paused and front.game == null)
	assert_true(is_equal_approx(AudioManager._music.volume_linear, 0.85))
	assert_true(is_equal_approx(Settings.volume("Music"), music_volume))
	tree.root.remove_child(front)
	front.free()
	tree.paused = false
	GameClock.reset()


func test_starter_watch_holds_three_nights_on_each_map_without_orders() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	for map in SessionFront.MAPS:
		var game := SessionFront.GAME.instantiate() as Main
		game.selected_map = map
		tree.root.add_child(game)
		var w := game.world
		w.horde.rng.seed = map.map_seed
		assert_eq(w.perimeter.towers.size(), 1, map.display_name)
		assert_true(not w.grid.barriers.is_empty() and w.perimeter.orders.is_empty())
		for barrier: BarrierSegment in w.grid.barriers.values():
			assert_true(barrier.blocks() and w.grid.get_cost(barrier.cell) == Grid.BLOCKED)
		assert_eq(Economy.stock, w.plots.rules.start_resources)
		var initial_people := w.safety.people.size()
		var rounds := Economy.get_amount(&"ammo")
		var attackers := 0
		var step := 1.0 / w.plots.rules.sim_ticks_per_second
		while not GameClock.ended:
			GameClock._advance(step)
			attackers += w.horde.queued
			w.horde._process(step)
			if w._dirty:
				w._build_now()
			w.zombies._process(step)
			if GameClock.day >= 4 and (w.zombies.count() == 0 or GameClock.is_night()):
				break
		assert_true(GameClock.day == 4 and not GameClock.ended, map.display_name)
		assert_true(is_instance_valid(w.command_post) and w.command_post.health > 0)
		assert_eq(w.safety.people.size(), initial_people, map.display_name)
		assert_eq(w.zombies.count(), 0, map.display_name)
		assert_eq(attackers, 64, "Nights 1–3 must include the first major horde")
		assert_eq(rounds - Economy.get_amount(&"ammo"), attackers, map.display_name)
		tree.root.remove_child(game)
		game.free()
	GameClock.reset()
