extends TestCase

const B := FlowField.BLOCKED
const N := FlowField.NONE


func _open(w: int, h: int) -> PackedInt32Array:
	var cost := PackedInt32Array()
	cost.resize(w * h)
	cost.fill(1)
	return cost


func _dir(field: FlowField, x: int, y: int) -> int:
	return field.direction[y * field.size.x + x]


func test_three_by_three_points_to_centre() -> void:
	var field := FlowField.new()
	field.build(_open(3, 3), Vector2i(3, 3), PackedInt32Array([4]))
	assert_eq(_dir(field, 0, 0), 3, "top-left -> SE")
	assert_eq(_dir(field, 1, 0), 4, "top-middle -> S")
	assert_eq(_dir(field, 2, 1), 6, "right-middle -> W")
	assert_eq(_dir(field, 1, 1), N, "goal has no direction")
	assert_eq(field.integration[0], 14, "diagonal step cost")
	assert_eq(field.integration[1], 10, "straight step cost")


func test_wall_forces_path_around() -> void:
	# 5x3, wall in column 2 rows 0-1, goal at (4,0). Path must go through (2,2).
	var cost := _open(5, 3)
	cost[2] = B
	cost[7] = B
	var field := FlowField.new()
	field.build(cost, Vector2i(5, 3), PackedInt32Array([4]))
	assert_true(field.integration[0] != FlowField.UNREACHED, "start reachable")
	assert_eq(_dir(field, 2, 2), 2, "gap tile -> E")
	assert_eq(_dir(field, 1, 1), 4, "next to wall -> S (no corner cut)")


func test_enclosed_tile_unreached() -> void:
	var cost := _open(5, 5)
	for i in [6, 7, 8, 11, 13, 16, 17, 18]:
		cost[i] = B
	var field := FlowField.new()
	field.build(cost, Vector2i(5, 5), PackedInt32Array([0]))
	assert_eq(field.integration[12], FlowField.UNREACHED, "enclosed integration")
	assert_eq(field.direction[12], N, "enclosed direction")
	assert_eq(field.direction_at(Vector2i(2, 2)), Vector2.ZERO, "direction_at none")


func test_no_corner_cutting() -> void:
	# Goal (1,0). Blocked (1,1). From (0,1)... diagonal to (1,0) would pass (1,1)? no:
	# (0,1)->(1,0) passes sides (1,1) and (0,0). (1,1) blocked, so go N first.
	var cost := _open(2, 2)
	cost[3] = B
	var field := FlowField.new()
	field.build(cost, Vector2i(2, 2), PackedInt32Array([1]))
	assert_eq(_dir(field, 0, 1), 0, "(0,1) -> N, not NE")


func test_rubble_costs_more() -> void:
	# 3x1 strip: goal at 2, rubble at 1.
	var cost := PackedInt32Array([1, 3, 1])
	var field := FlowField.new()
	field.build(cost, Vector2i(3, 1), PackedInt32Array([2]))
	assert_eq(field.integration[1], 30, "rubble step")
	assert_eq(field.integration[0], 40, "two steps")


func test_blocked_goal_still_seeds() -> void:
	# Buildings are blocked tiles but still goals.
	var cost := _open(3, 1)
	cost[2] = B
	var field := FlowField.new()
	field.build(cost, Vector2i(3, 1), PackedInt32Array([2]))
	assert_eq(_dir(field, 1, 0), 2, "-> E towards building")
	assert_eq(field.direction_at(Vector2i(9, 9)), Vector2.ZERO, "out of bounds")


func test_native_and_script_fields_agree_for_every_tile_and_tie() -> void:
	if not ClassDB.class_exists(&"TownFlowNative"):
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = 107
	var size := Vector2i(29, 33)
	for sample in 10:
		var cost := _open(size.x, size.y)
		for i in cost.size():
			cost[i] = [-1, 1, 1, 1, 3, 8][rng.randi_range(0, 5)]
		var physical := cost.duplicate()
		# A closed gate can be breached but blocks a diagonal corner.
		cost[24] = 40
		physical[24] = B
		var goals := PackedInt32Array([13, 14, 13, 520])
		var actual := FlowField.new()
		actual.build(cost, size, goals, physical)
		var expected := FlowField.new()
		expected.size = size
		expected.integration = _open(size.x, size.y)
		expected.integration.fill(FlowField.UNREACHED)
		expected.direction.resize(cost.size())
		expected.direction.fill(N)
		expected._integrate(cost, goals, physical)
		assert_true(actual.integration == expected.integration, "Distances on sample %d" % sample)
		assert_true(actual.direction == expected.direction, "Tie-breaking on sample %d" % sample)
