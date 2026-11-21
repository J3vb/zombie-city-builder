extends TestCase

const HOUSE := preload("res://data/buildings/house.tres")


func test_place_spends_and_occupies() -> void:
	var fx := WorldFixture.new()
	var world := fx.create()
	var wood: int = Economy.get_amount(&"wood")
	world.build_tool.select(HOUSE)
	assert_true(world.build_tool.place(Vector2i(20, 20)), "placed")
	assert_eq(Economy.get_amount(&"wood"), wood - 20, "wood spent")
	assert_true(world.grid.building_at(Vector2i(21, 21)) != null, "occupied")
	fx.destroy()


func test_blocked_place_changes_nothing() -> void:
	var fx := WorldFixture.new()
	var world := fx.create()
	var wood: int = Economy.get_amount(&"wood")
	world.build_tool.select(HOUSE)
	# Command Post sits here.
	assert_true(not world.build_tool.place(world.map_def.command_post_cell), "blocked")
	# Border tile.
	assert_true(not world.build_tool.place(Vector2i(0, 5)), "border")
	assert_eq(Economy.get_amount(&"wood"), wood, "no wood spent")
	fx.destroy()


func test_unaffordable_place_changes_nothing() -> void:
	var fx := WorldFixture.new()
	var world := fx.create()
	var empty: Dictionary[StringName, int] = {&"wood": 5}
	Economy.reset(empty)
	world.build_tool.select(HOUSE)
	assert_true(not world.build_tool.place(Vector2i(20, 20)), "too expensive")
	assert_true(world.grid.building_at(Vector2i(20, 20)) == null, "nothing placed")
	assert_eq(Economy.get_amount(&"wood"), 5, "wood unchanged")
	fx.destroy()


func test_flow_field_points_to_buildings() -> void:
	var fx := WorldFixture.new()
	var world := fx.create()
	var cp := world.map_def.command_post_cell
	var west := Vector2i(cp.x - 5, cp.y + 1)
	assert_eq(world.flow_field.direction_at(west), Vector2.RIGHT, "west of CP -> east")
	fx.destroy()
