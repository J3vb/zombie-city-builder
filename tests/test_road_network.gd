extends TestCase

const HOUSE := preload("res://data/buildings/house.tres")


func test_opposite_branches_snap_to_one_junction() -> void:
	var fx := WorldFixture.new()
	var world := fx.create()
	var net := world.roads
	var start := net.entrance
	var joint := start + Vector2(0, 128)
	net.add_road(PackedVector2Array([start, start + Vector2(0, 256)]))
	net.add_road(PackedVector2Array([joint, joint + Vector2(144, 0)]))
	var cursor := joint + Vector2(-2, 12)
	assert_eq(net.connection_point(cursor), joint, "prefer the junction beside the cursor")
	var branch := net.add_road(PackedVector2Array([cursor, joint + Vector2(-144, 12)]))
	assert_true(branch != null, "opposite branch can join the existing T")
	assert_eq(net.graph[joint].size(), 4, "all four arms use one graph node")
	assert_eq(net.connection_point(joint + Vector2(80, 80)), Vector2.INF, "open ground")
	fx.destroy()


func test_pavement_covers_outside_corner_until_branch_is_removed() -> void:
	var fx := WorldFixture.new()
	var world := fx.create()
	var net := world.roads
	var joint := net.entrance + Vector2(0, 160)
	net.add_road(PackedVector2Array([net.entrance, joint]))
	var sample_point := world.to_view(joint + Vector2(-8, 8))
	var paving := world.road_tool._junctions._paving
	assert_true(not _covers(paving.mesh, sample_point), "dead end keeps its original footprint")
	var corner := net.add_road(PackedVector2Array([joint, joint + Vector2(160, 0)]))
	assert_true(_covers(paving.mesh, sample_point), "the outside wedge is paved")
	net.remove_road(corner.id)
	assert_true(not _covers(paving.mesh, sample_point), "removal clears orphan paving")
	fx.destroy()


func _covers(mesh: Mesh, point: Vector3) -> bool:
	if mesh == null:
		return false
	var vertices := mesh.get_faces()
	for i in range(0, vertices.size(), 3):
		var a := vertices[i]
		var b := vertices[i + 1]
		var c := vertices[i + 2]
		if Geometry2D.point_is_inside_triangle(
			Vector2(point.x, point.z), Vector2(a.x, a.z), Vector2(b.x, b.z), Vector2(c.x, c.z)
		):
			return true
	return false


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


func test_click_to_build_chain_back_out_and_retry_blocked_end() -> void:
	var fx := WorldFixture.new()
	var world := fx.create()
	var tool := world.road_tool
	var start := world.roads.entrance
	tool.select()
	_click(world, start)
	_click(world, start + Vector2(0, -128))
	assert_eq(world.roads.roads.size(), 0, "blocked click spends nothing and keeps the start")
	assert_eq(tool.points.size(), 1)
	_click(world, start + Vector2(4, 128))
	assert_eq(world.roads.roads.size(), 1, "second click builds immediately")
	var end := tool.points[0]
	assert_true(absf(end.x - start.x) < 0.01, "angle guide straightened the street")
	world.camera.rotation.y = 0.7
	_click(world, end + Vector2(145, 1))
	assert_eq(world.roads.roads.size(), 2, "next click builds a connected segment after orbiting")
	_click(world, end, MOUSE_BUTTON_RIGHT)
	assert_true(tool.active and tool.points.is_empty(), "right click releases chain")
	assert_eq(world.roads.roads.size(), 2, "built segments survive cancellation")
	_click(world, end, MOUSE_BUTTON_RIGHT)
	assert_true(not tool.active, "right click with no pending anchor closes the tool")
	fx.destroy()


func test_freeform_retains_curve_tangent_and_right_click_releases_handle() -> void:
	var fx := WorldFixture.new()
	var world := fx.create()
	var tool := world.road_tool
	var start := world.roads.entrance
	tool.select(RoadTool.Mode.FREEFORM)
	_click(world, start)
	_click(world, start + Vector2(0, 110))
	assert_true(world.roads.roads.is_empty(), "choosing a handle leaves ground untouched")
	_click(world, start, MOUSE_BUTTON_RIGHT)
	assert_eq(tool.points.size(), 1, "back up only the handle")
	_click(world, start + Vector2(0, 110))
	_click(world, start + Vector2(112, 160))
	var first: Street = world.roads.roads.values()[0]
	assert_true(first.quadratic, "bend handle controls a quadratic curve")
	assert_true(first.nearest(first.controls[1]).distance > 10.0, "road bends inside its handle")
	_click(world, start + Vector2(230, 140))
	var next: Street = world.roads.roads.values()[1]
	var exit_dir := first.controls[1].direction_to(first.controls[2])
	assert_true(exit_dir.dot(next.controls[0].direction_to(next.controls[1])) > 0.999)
	assert_true(world.roads.reachable.has(next.line[-1]), "smooth extension is routable")
	fx.destroy()


func test_crossing_connects_both_roads_and_removal_restores_trunk() -> void:
	var fx := WorldFixture.new()
	var world := fx.create()
	var net := world.roads
	var start := net.entrance
	var trunk := net.add_road(PackedVector2Array([start, start + Vector2(0, 272)]))
	var joint := start + Vector2(0, 135)
	var cross := net.add_road(
		PackedVector2Array([joint + Vector2.LEFT * 101, joint + Vector2.RIGHT * 146])
	)
	assert_true(cross != null, "drawing through a street creates a junction")
	var node := net.connection_point(joint)
	assert_eq(net.graph[node].size(), 4, "crossing splits both graph edges")
	assert_true(net.reachable.has(cross.line[-1]) and net.reachable.has(cross.line[0]))
	assert_eq(net.add_road(trunk.controls), null, "drawing over an identical street stays invalid")
	assert_true(net.remove_road(cross.id))
	assert_true(not net.graph.has(node), "removing crossing removes its derived node")
	assert_true(net.reachable.has(trunk.line[-1]))
	fx.destroy()


func test_reload_legacy_street_and_curved_crossing_with_stable_frontage() -> void:
	var fx := WorldFixture.new()
	var world := fx.create()
	var net := world.roads
	var p := net.entrance
	var trunk := net.add_road(PackedVector2Array([p, p + Vector2.DOWN * 360]))
	var curve := net.add_road(
		PackedVector2Array([p + Vector2(-130, 125), p + Vector2(15, 200), p + Vector2(150, 125)]),
		true,
		true
	)
	assert_true(curve != null, "a curved road can cross a straight street")
	var plot := world.plots.reserve(p + Vector2(8, 285), world.plots.rules.plot_frontage)
	assert_true(plot != null)
	var snapshot := SaveLayout.capture(world, {})
	snapshot.roads[0].erase("quadratic")
	var before := net.graph.duplicate(true)
	fx.destroy()
	world = fx.create()
	var loader := RestoreGround.new()
	assert_true(loader._roads(world, snapshot.roads), "load old and new road records together")
	assert_true(loader._plots(world, snapshot.plots), "restore the reserved plot")
	assert_eq(world.roads.graph, before)
	assert_eq(world.roads.roads[curve.id].line, curve.line)
	assert_eq(world.plots.plots[plot.id].road_id, trunk.id)
	assert_true(world.plots.connected(world.plots.plots[plot.id]))
	fx.destroy()


func _click(world: World, point: Vector2, button: MouseButton = MOUSE_BUTTON_LEFT) -> void:
	world.camera.lens.force_update_transform()
	var click := InputEventMouseButton.new()
	click.button_index = button
	click.pressed = true
	click.position = world.camera.lens.unproject_position(world.to_view(point))
	world.road_tool._unhandled_input(click)
