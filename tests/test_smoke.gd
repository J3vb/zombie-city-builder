extends TestCase


func test_autoloads_exist() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	assert_true(tree.root.has_node("EventBus"), "EventBus autoload missing")
	assert_true(tree.root.has_node("GameClock"), "GameClock autoload missing")
	assert_true(tree.root.has_node("Economy"), "Economy autoload missing")


func test_balance_loads() -> void:
	var balance := load("res://data/balance.tres") as BalanceDef
	assert_true(balance != null, "balance.tres did not load as BalanceDef")
	assert_true(balance.night_at > balance.dusk_at, "night must start after dusk")


func test_starter_map_loads() -> void:
	var map := load("res://data/maps/starter_map.tres") as MapDef
	assert_true(map != null, "starter_map.tres did not load as MapDef")
	assert_eq(map.size, Vector2i(128, 128), "map size")


func test_main_scene_loads() -> void:
	var scene := load("res://scenes/main/main.tscn") as PackedScene
	assert_true(scene != null, "main.tscn did not load")
