extends TestCase

const HOUSE := preload("res://data/buildings/house.tres")


func test_destroyed_building_releases_cells() -> void:
	var fx := WorldFixture.new()
	var world := fx.create()
	var destroyed: Array[Node] = []
	var on_destroyed := func(b: Node) -> void: destroyed.append(b)
	EventBus.building_destroyed.connect(on_destroyed)
	var house := world.spawn_building(HOUSE, Vector2i(20, 20))
	assert_true(not world.grid.is_free(house.cells), "occupied")
	house.take_damage(HOUSE.max_health)
	EventBus.building_destroyed.disconnect(on_destroyed)
	assert_true(world.grid.is_free(Grid.cells_of(Vector2i(20, 20), HOUSE.size)), "released")
	assert_eq(destroyed.size(), 1, "destroyed signal")
	fx.destroy()


func test_command_post_ends_game() -> void:
	var fx := WorldFixture.new()
	var world := fx.create()
	var days: Array[int] = []
	var on_over := func(day: int) -> void: days.append(day)
	EventBus.game_over.connect(on_over)
	world.command_post.take_damage(99999)
	EventBus.game_over.disconnect(on_over)
	assert_eq(days, [1] as Array[int], "game_over day")
	fx.destroy()


func test_demolish_refunds_half() -> void:
	var fx := WorldFixture.new()
	var world := fx.create()
	var house := world.spawn_building(HOUSE, Vector2i(20, 20))
	var before: int = Economy.get_amount(&"wood")
	house.demolish()
	assert_eq(Economy.get_amount(&"wood"), before + 10, "refund")
	fx.destroy()


func test_repeated_demolition_preserves_refund_and_replacement() -> void:
	var fx := WorldFixture.new()
	var world := fx.create()
	var anchor := Vector2i(20, 20)
	var original := world.spawn_building(HOUSE, anchor)
	var destroyed: Array[Node] = []
	var on_destroyed := func(b: Node) -> void: destroyed.append(b)
	EventBus.building_destroyed.connect(on_destroyed)
	var wood := Economy.get_amount(&"wood")
	original.demolish()
	var replacement := world.spawn_building(HOUSE, anchor)
	original.demolish()
	original.take_damage(HOUSE.max_health)
	EventBus.building_destroyed.disconnect(on_destroyed)
	assert_eq(destroyed, [original], "one removal")
	assert_eq(Economy.get_amount(&"wood"), wood + 10, "one refund")
	for cell in original.cells:
		assert_eq(world.grid.building_at(cell), replacement, "replacement owns its footprint")
	fx.destroy()


func test_house_footprint_is_independent_of_its_view() -> void:
	var fx := WorldFixture.new()
	var world := fx.create()
	var anchor := Vector2i(20, 20)
	var house := world.spawn_building(HOUSE, anchor)
	var view := house.get_node("View") as Node2D
	var bounds := Rect2(
		Vector2(anchor) * world.tile_size(), Vector2(HOUSE.size) * world.tile_size()
	)
	assert_eq(view.position, bounds.position, "draws at the footprint")
	view.position += Vector2(600, 100)
	assert_eq(house.sim_bounds(), bounds, "moving the art preserves the footprint")
	assert_eq(house.sim_center(), bounds.get_center(), "center of an even-sized footprint")
	assert_eq(world.spawn_building(HOUSE, anchor), null, "unpaid spawns also check for overlap")
	fx.destroy()
