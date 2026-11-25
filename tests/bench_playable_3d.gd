extends SceneTree
## Render the playable town with 500 simulated Walkers. Pass -- night for the night run.

const WALKERS := 500
const WARMUP_US := 2000000
const SAMPLE_US := 8000000

var gate: RefCounted
var builds := PackedFloat64Array()
var previous_field: RefCounted


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var main := (load("res://scenes/main/main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	current_scene = main
	var world: Node = main.get("world")
	var clock := root.get_node("GameClock")
	var night := OS.get_cmdline_user_args().has("night")
	if night:
		clock.set("time_of_day", 0.75)
	# Use a fixed crowd in camera range. Natural waves would change the sample count.
	world.horde.set_process(false)
	world.camera.set_process(false)
	var center: Vector2 = world.command_post.sim_center()
	var walker := load("res://data/zombies/walker.tres")
	for i in WALKERS:
		var angle := TAU * (i % 100) / 100.0
		var radius := (14 + i / 100) * float(world.grid.tile_size)
		var point := center + Vector2.RIGHT.rotated(angle) * radius
		if not world.zombies.spawn(point, walker):
			push_error("Could not spawn benchmark Walker %d" % i)
			quit(1)
			return
	var wheel := InputEventMouseButton.new()
	wheel.button_index = MOUSE_BUTTON_WHEEL_DOWN
	wheel.pressed = true
	for i in 6:
		world.camera._unhandled_input(wheel)
	var rebuild := OS.get_cmdline_user_args().has("rebuild")
	if rebuild:
		var gate_def := load("res://data/defenses/gate.tres")
		var cell := Vector2i(60, 70)
		if not world.perimeter.order(gate_def, cell, cell):
			push_error("Could not place the benchmark gate")
			quit(1)
			return
		gate = world.grid.barriers[cell]
		world.perimeter.add_work(gate, gate_def.build_seconds)
		previous_field = world.flow_field
	var samples := PackedFloat64Array()
	var updates := PackedFloat64Array()
	var last_edit := 0
	var start := Time.get_ticks_usec()
	var last := start
	while last - start < WARMUP_US + SAMPLE_US:
		await RenderingServer.frame_post_draw
		var now := Time.get_ticks_usec()
		if last - start >= WARMUP_US:
			samples.append((now - last) / 1000.0)
			updates.append(world.zombies.last_update_ms)
			if rebuild and world.flow_field != previous_field:
				builds.append(world.last_build_ms)
				previous_field = world.flow_field
			if rebuild and now - last_edit >= 250000:
				world.perimeter.set_gate(gate, not gate.opened)
				last_edit = now
		last = now
	if samples.is_empty() or world.zombies.count() != WALKERS or clock.get("speed") == 0:
		push_error("Benchmark ended without a full active crowd")
		quit(1)
		return
	var elapsed := 0.0
	for ms in samples:
		elapsed += ms
	samples.sort()
	var p95 := samples[ceili(samples.size() * 0.95) - 1]
	print(
		(
			"RESULT %s: %d Walkers, %.1f FPS, frame p95 %.2f ms"
			% ["night" if night else "day", WALKERS, samples.size() * 1000.0 / elapsed, p95]
		)
	)
	updates.sort()
	print("RESULT Walker update p95 %.2f ms" % updates[ceili(updates.size() * 0.95) - 1])
	if rebuild:
		if builds.size() < 2:
			push_error("No repeated gate rebuilds completed in the sample")
			quit(1)
			return
		builds.sort()
		print(
			(
				"RESULT %d worker rebuilds, completion p95 %.2f ms, slowest frame %.2f ms"
				% [builds.size(), builds[ceili(builds.size() * 0.95) - 1], samples[-1]]
			)
		)
	quit()
