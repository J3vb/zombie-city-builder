extends TestCase

const HOUSE := preload("res://data/buildings/house.tres")


func test_curve_branches_keep_stable_ids_and_junction_ownership() -> void:
	var fx := WorldFixture.new()
	var world := fx.create()
	var net := world.roads
	var start := net.entrance
	var trunk := net.add_road(PackedVector2Array([start, start + Vector2(0, 256)]))
	assert_true(trunk != null, "street from the Station 4 marker")
	var joint := start + Vector2(0, 128)
	var branch := net.add_road(PackedVector2Array([joint + Vector2(3, 1), joint + Vector2(145, 1)]))
	assert_true(branch != null, "branch snaps onto the middle")
	assert_true(net.reachable.has(branch.line[-1]), "both roads reach Station 4")
	assert_eq(net.graph[branch.line[0]].size(), 3, "T splits trunk into two graph edges")
	var disconnected := net.add_road(
		PackedVector2Array([start + Vector2(-96, 0), start + Vector2(-96, 256)])
	)
	assert_true(
		not net.reachable.has(disconnected.line[0]), "nearby parallel street stays disconnected"
	)
	var cell := world.grid.world_to_cell(joint)
	assert_true(world.grid.get_cost(cell) > 0, "Walkers can use the road")
	assert_eq(world.spawn_building(HOUSE, cell), null, "building cannot occupy the corridor")
	net.remove_road(branch.id)
	assert_eq(net.roads[trunk.id], trunk, "original ID and street survive removal")
	assert_true(world.grid.road_cells.has(cell), "junction still belongs to trunk")
	fx.destroy()


func test_entire_curve_and_width_are_checked_without_side_effects() -> void:
	var fx := WorldFixture.new()
	var world := fx.create()
	var net := world.roads
	var t := float(world.grid.tile_size)
	var points := PackedVector2Array([Vector2(8, 92) * t, Vector2(42, 92) * t])
	assert_eq(net.add_road(points), null, "dry endpoints across water")
	assert_eq(
		net.add_road(PackedVector2Array([Vector2(9, 89.75) * t, Vector2(41, 89.75) * t])),
		null,
		"outer edge clips water"
	)
	var start := net.entrance
	assert_eq(net.add_road(PackedVector2Array([start, start + Vector2(0, 6)])), null, "too short")
	assert_eq(
		net.add_road(PackedVector2Array([start, start + Vector2(0, -160)])),
		null,
		"crosses Command Post"
	)
	assert_eq(
		net.add_road(
			PackedVector2Array(
				[start, start + Vector2(160, 160), start + Vector2(0, 160), start + Vector2(160, 0)]
			)
		),
		null,
		"self crossing"
	)
	assert_true(
		net.roads.is_empty() and world.grid.road_cells.is_empty(), "rejections reserve nothing"
	)
	fx.destroy()


func test_draw_s_bend_from_two_angles_and_cancel_draft() -> void:
	var fx := WorldFixture.new()
	var world := fx.create()
	var tool := world.road_tool
	var start := world.roads.entrance
	var points := PackedVector2Array(
		[start, start + Vector2(32, 80), start + Vector2(-32, 168), start + Vector2(0, 248)]
	)
	var stock := Economy.stock.duplicate()
	tool.select()
	tool.add_point(points[0])
	tool.add_point(points[1])
	tool.undo()
	assert_eq(tool.points.size(), 1, "undo only removes the last control point")
	tool.clear()
	assert_true(
		world.roads.roads.is_empty() and world.grid.road_cells.is_empty(),
		"cancel leaves land untouched"
	)
	assert_eq(Economy.stock, stock, "cancel leaves stock intact")
	tool.select()
	world.camera.position = world.to_view(points[1])
	for i in points.size():
		world.camera.rotation.y = 0.9 if i > 1 else 0.0
		world.camera.lens.force_update_transform()
		var click := InputEventMouseButton.new()
		click.button_index = MOUSE_BUTTON_LEFT
		click.pressed = true
		click.position = world.camera.lens.unproject_position(world.to_view(points[i]))
		tool._unhandled_input(click)
	assert_true(tool.finish(), "finish S-bend through real placement tool")
	assert_eq(world.roads.roads.size(), 1, "one street")
	var road: Street = world.roads.roads.values()[0]
	assert_true(road.line.size() > points.size(), "surface uses a baked curve")
	assert_true(world.roads.reachable.has(road.line[-1]), "S-bend connects to station")
	fx.destroy()
