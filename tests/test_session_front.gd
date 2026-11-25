extends TestCase
## Exercise title, actual map selection, pause, defeat and return to the title.


func test_mill_crossing_and_pause_keep_the_same_town() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	var front := (load("res://scenes/main/title.tscn") as PackedScene).instantiate() as SessionFront
	tree.root.add_child(front)
	assert_true(tree.paused and front.game == null)
	(front.get_node("%Map") as OptionButton).select(1)
	(front.get_node("%Start") as Button).pressed.emit()
	var w := front.game.world
	assert_eq(w.map_def.display_name, "Mill Crossing")
	assert_eq(w.grid.size, Vector2i(144, 112))
	var terrain := StarterMap.generate(w.map_def)
	assert_eq(terrain[60 * 144 + 70], TerrainSet.Kind.WATER)
	assert_eq(terrain[36 * 144 + 70], TerrainSet.Kind.GROUND)
	GameClock.set_speed(3)
	front.pause_game()
	assert_true(tree.paused and not w.can_process())
	front.resume_game()
	assert_true(not tree.paused and w.can_process())
	assert_eq(GameClock.speed, 3)
	assert_true(w == front.game.world)
	EventBus.game_over.emit(3)
	assert_true(GameClock.ended)
	(front.game.get_node("GameOver/Center/Panel/Box/Title") as Button).pressed.emit()
	assert_true(tree.paused and front.game == null)
	tree.root.remove_child(front)
	front.free()
	tree.paused = false
	GameClock.reset()
