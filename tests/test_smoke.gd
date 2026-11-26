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
	var terrain := StarterMap.generate(map)
	for lake in map.lakes:
		var center := lake.get_center()
		assert_eq(terrain[center.y * map.size.x + center.x], TerrainSet.Kind.WATER)
		assert_eq(terrain[lake.position.y * map.size.x + lake.position.x], TerrainSet.Kind.GROUND)


func test_world_scene_loads() -> void:
	var scene := load("res://scenes/world/world.tscn") as PackedScene
	assert_true(scene != null, "world.tscn did not load")


func test_main_scene_loads() -> void:
	var scene := load("res://scenes/main/main.tscn") as PackedScene
	assert_true(scene != null, "main.tscn did not load")


func test_playable_world_draws_generated_terrain() -> void:
	var fixture := WorldFixture.new()
	var world := fixture.create()
	var chunks := world.terrain.get_children()
	var chunky := TerrainMesh.CHUNK_SIZE
	assert_eq(
		chunks.size(),
		ceili(float(world.grid.size.x) / chunky) * ceili(float(world.grid.size.y) / chunky),
		"Every terrain chunk is present"
	)
	var last := (chunks.back() as MeshInstance3D).mesh.get_aabb()
	assert_eq(last.end.x, world.grid.size.x * world.view_tile(), "full width")
	assert_eq(last.end.z, world.grid.size.y * world.view_tile(), "full depth")
	var has_water := false
	var has_bank := false
	for chunk: MeshInstance3D in chunks:
		if chunk.mesh.get_aabb().position.y < -0.25:
			has_water = true
			var vertices: PackedVector3Array = chunk.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
			for vertex in vertices:
				if vertex.y < -0.01 and vertex.y > -0.24:
					has_bank = true
					break
	assert_true(has_water, "water is recessed in the playable mesh")
	assert_true(has_bank, "the shore slopes between land and water")
	fixture.destroy()
