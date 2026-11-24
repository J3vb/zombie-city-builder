extends SceneTree
## Windows render benchmark. Run with --script res://tests/bench_residents.gd at 1080p.

const PEOPLE := 50
const WALKERS := 500


func _initialize() -> void:
	call_deferred("_run")


func _district(w: Node) -> bool:
	var t := float(w.grid.tile_size)
	var entrance: Vector2 = w.roads.entrance
	var trunk_start := entrance + Vector2.DOWN * 5 * t
	var end := Vector2(12.5 * t, trunk_start.y)
	if w.roads.add_road(PackedVector2Array([entrance, trunk_start])) == null:
		push_error("Station 4 entrance is blocked")
		return false
	if w.roads.add_road(PackedVector2Array([trunk_start, end])) == null:
		push_error("Cross street: " + w.roads.preview(PackedVector2Array([trunk_start, end])).error)
		return false
	for x: float in [14.5, 25.5, 36.5, 47.5]:
		var junction := Vector2(x * t, end.y)
		if w.roads.add_road(PackedVector2Array([junction, junction - Vector2(0, 36 * t)])) == null:
			push_error(
				(
					"Side street: "
					+ (
						w
						. roads
						. preview(PackedVector2Array([junction, junction - Vector2(0, 36 * t)]))
						. error
					)
				)
			)
			return false
		for row in range(2, 34, 4):
			for side: float in [-1.0, 1.0]:
				if w.jobs.residents.size() == PEOPLE:
					break
				var cursor := junction + Vector2(side * 8.0, -row * t)
				var plot: RefCounted = w.plots.reserve(cursor, w.plots.rules.plot_frontage)
				if plot != null:
					w.spawn_building(w.plots.house_def, plot.house_cells[0], plot)
	if w.jobs.residents.size() != PEOPLE:
		return false
	var garden: Resource = load("res://data/buildings/garden.tres")
	for resident in w.jobs.residents:
		var placed := false
		for reach in range(1, 9):
			for offset: Vector2i in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
				if w.spawn_building(garden, resident.cell + offset * reach) != null:
					placed = true
					break
			if placed:
				break
		if not placed:
			return false
	return true


func _run() -> void:
	var main := (load("res://scenes/main/main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	current_scene = main
	var w: Node = main.get("world")
	var clock := root.get_node("GameClock")
	clock.set_process(false)
	w.camera.set_process(false)
	w.horde.set_process(false)
	w.grower.paused = true
	if not _district(w):
		push_error(
			(
				"District setup failed at %d residents / %d jobs"
				% [w.jobs.residents.size(), w.jobs.sites.size()]
			)
		)
		quit(1)
		return
	var tick_start := Time.get_ticks_usec()
	w.jobs._tick(0.1)
	print(
		(
			"Initial assignment for 50 residents: %.1f ms"
			% ((Time.get_ticks_usec() - tick_start) / 1000.0)
		)
	)
	var staffed := 0
	for site in w.jobs.sites:
		if w.jobs.worker_at(site) != null:
			staffed += 1
	if staffed != PEOPLE:
		push_error("Only %d of %d sites staffed" % [staffed, PEOPLE])
		quit(1)
		return
	var center: Vector2 = Vector2(31, 51) * w.grid.tile_size
	w.camera.position = w.to_view(center)
	w.camera.distance = 215
	w.camera._apply()
	var walker: Resource = load("res://data/zombies/walker.tres")
	for i in WALKERS:
		var point: Vector2 = (
			center
			+ Vector2.RIGHT.rotated(TAU * (i % 100) / 100.0) * (26 + i / 100) * w.grid.tile_size
		)
		if not w.zombies.spawn(point, walker):
			push_error("Could not populate benchmark crowd")
			quit(1)
			return
	clock.set_process(true)
	var samples := PackedFloat64Array()
	var last := Time.get_ticks_usec()
	var start := last
	while last - start < 8000000:
		await RenderingServer.frame_post_draw
		var now := Time.get_ticks_usec()
		if last - start >= 2000000:
			samples.append((now - last) / 1000.0)
		last = now
	var total := 0.0
	for ms in samples:
		total += ms
	samples.sort()
	print(
		(
			"RESULT %d residents, %d Walkers, %.1f FPS, p95 %.2f ms"
			% [
				w.jobs.residents.size(),
				w.zombies.count(),
				1000.0 * samples.size() / total,
				samples[ceili(samples.size() * 0.95) - 1]
			]
		)
	)
	quit(0 if w.zombies.count() == WALKERS and w.jobs.residents.size() == PEOPLE else 1)
