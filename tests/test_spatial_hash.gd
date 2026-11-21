extends TestCase


func _hash_with(points: PackedVector2Array) -> SpatialHash:
	var h := SpatialHash.new()
	h.setup(Vector2(256, 256), 64.0)
	h.rebuild(points, points.size())
	return h


func test_radius_is_inclusive() -> void:
	var points := PackedVector2Array([Vector2(109, 100), Vector2(110, 100), Vector2(111, 100)])
	var h := _hash_with(points)
	var out := PackedInt32Array()
	var n := h.query(Vector2(100, 100), 10.0, out)
	assert_eq(n, 2, "count")
	var got := [out[0], out[1]]
	got.sort()
	assert_eq(got, [0, 1], "indices")


func test_across_bucket_edges() -> void:
	var points := PackedVector2Array([Vector2(60, 60), Vector2(68, 68), Vector2(200, 200)])
	var h := _hash_with(points)
	var out := PackedInt32Array()
	assert_eq(h.query(Vector2(64, 64), 8.0, out), 2, "two near the corner")


func test_empty_query() -> void:
	var h := _hash_with(PackedVector2Array())
	var out := PackedInt32Array()
	assert_eq(h.query(Vector2(10, 10), 50.0, out), 0, "empty")


func test_out_buffer_grows() -> void:
	var points := PackedVector2Array()
	for i in 40:
		points.append(Vector2(30, 30))
	var h := _hash_with(points)
	var out := PackedInt32Array()
	assert_eq(h.query(Vector2(30, 30), 1.0, out), 40, "all found")
	assert_true(out.size() >= 40, "buffer grew")
