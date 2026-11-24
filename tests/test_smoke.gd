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


func test_world_scene_loads() -> void:
	var scene := load("res://scenes/world/world.tscn") as PackedScene
	assert_true(scene != null, "world.tscn did not load")


func test_main_scene_loads() -> void:
	var scene := load("res://scenes/main/main.tscn") as PackedScene
	assert_true(scene != null, "main.tscn did not load")


func test_playable_world_draws_generated_terrain() -> void:
	var fixture := WorldFixture.new()
	var world := fixture.create()
	assert_eq(world.terrain.get_used_rect(), Rect2i(Vector2i.ZERO, world.grid.size), "map extent")
	for cell in [Vector2i.ZERO, Vector2i(3, 2), Vector2i(40, 30), Vector2i(10, 90)]:
		var kind := world.grid.terrain_types[world.grid.index(cell)]
		assert_eq(world.terrain.get_cell_atlas_coords(cell), Vector2i(kind, 0), "tile %s" % cell)
	fixture.destroy()
