extends SceneTree
## Times a full flow-field build on the starter map size.
## Run: godot --headless --script res://tests/bench_flow_field.gd
## Not run in CI. Budget: 8 ms (docs/DESIGN.md).


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.has("require-native") and not ClassDB.class_exists(&"TownFlowNative"):
		push_error("The native flow-field solver did not load")
		quit(1)
		return
	var size := Vector2i(128, 128)
	var cost := PackedInt32Array()
	cost.resize(size.x * size.y)
	cost.fill(1)
	for i in range(0, cost.size(), 7):
		cost[i] = 3
	var goals := PackedInt32Array()
	for y in range(60, 66):
		for x in range(60, 66):
			goals.append(y * size.x + x)
	var field := FlowField.new()
	field.build(cost, size, goals)
	var runs := 10
	var start := Time.get_ticks_usec()
	for i in runs:
		field.build(cost, size, goals)
	var ms := (Time.get_ticks_usec() - start) / 1000.0 / runs
	print("flow field 128x128: %.2f ms per build (budget 8 ms)" % ms)
	quit(1 if args.has("enforce-budget") and ms > 8.0 else 0)
