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


func test_competing_claim_refunds_the_whole_purchase() -> void:
	var fx := WorldFixture.new()
	var world := fx.create()
	var anchor := Vector2i(20, 20)
	var def := HOUSE.duplicate() as BuildingDef
	def.cost = {&"wood": 10, &"scrap": 2}
	var before := Economy.stock.duplicate()
	var winner: Array[Building] = []
	var on_spend := func(_id: StringName, _amount: int) -> void:
		winner.append(world.spawn_building(HOUSE, anchor))
	EventBus.resource_changed.connect(on_spend, CONNECT_ONE_SHOT)
	world.build_tool.select(def)
	assert_true(not world.build_tool.place(anchor), "competing claim wins")
	assert_eq(Economy.stock, before, "all resources returned")
	assert_eq(winner.size(), 1, "one competing placement")
	assert_eq(world.grid.building_at(anchor), winner[0], "original owner remains")
	fx.destroy()


func test_mouse_places_on_the_same_grid_after_orbit() -> void:
	var fx := WorldFixture.new()
	var world := fx.create()
	var cell := world.map_def.command_post_cell + Vector2i(-3, 1)
	var ground := world.to_view(world.grid.cell_to_world(cell))
	world.build_tool.select(HOUSE)
	for angle in [0.0, 1.3]:
		world.camera.rotation.y = angle
		world.camera.lens.force_update_transform()
		var screen := world.camera.lens.unproject_position(ground)
		assert_eq(world.build_tool.cell_at_screen(screen), cell, "picked cell after orbit")
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	click.position = world.camera.lens.unproject_position(ground)
	world.build_tool._unhandled_input(click)
	assert_eq(world.grid.building_at(cell).def, HOUSE, "mouse placed a house")
	assert_eq(
		world.build_tool.cell_at_screen(Vector2(-100, -100)), BuildTool.NO_CELL, "outside the view"
	)
	assert_eq(CameraRig.ray_to_ground(Vector3.UP, Vector3.RIGHT), null, "horizon")
	assert_eq(CameraRig.ray_to_ground(Vector3.UP, Vector3.UP), null, "sky")
	fx.destroy()
