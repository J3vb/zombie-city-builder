extends SceneTree
## Replay a fresh, paid opening against the normal hordes. Stop at defeat or dawn six.


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var main := (load("res://scenes/main/main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	current_scene = main
	var world: Node = main.world
	var clock := root.get_node("GameClock")
	var stock := root.get_node("Economy")
	world.horde.rng.seed = 4
	var entry: Vector2 = world.roads.entrance
	var tile: float = world.grid.tile_size
	if world.roads.add_road(PackedVector2Array([entry, entry + Vector2.DOWN * tile * 24])) == null:
		push_error("Opening street failed")
		quit(1)
		return
	for row in 5:
		for side: int in [-1, 1]:
			if row == 4 and side == 1:
				break
			var cursor := entry + Vector2(side * 8, (3 + row * 4) * tile)
			if world.plots.reserve(cursor, world.plots.rules.plot_frontage) == null:
				push_error("Opening home plot failed")
				quit(1)
				return
	var well := load("res://data/buildings/well.tres")
	var lumber := load("res://data/buildings/lumber_yard.tres")
	var field := load("res://data/buildings/farm.tres")
	if (
		world.try_place_building(lumber, Vector2i(72, 80)) == null
		or world.try_place_building(well, Vector2i(56, 76)) == null
	):
		push_error("Opening orders failed")
		quit(1)
		return
	world.grower.paint(Rect2i(55, 70, 3, 3), field)
	var step: float = 1.0 / world.plots.rules.sim_ticks_per_second
	var waves := 0
	var previous_day: int = clock.day
	var first_wave := false
	var post: Node = world.command_post
	while clock.day < 6 and not clock.ended:
		clock._advance(step)
		if world.horde.queued > 0 and not first_wave:
			first_wave = true
			waves += 1
			print(
				(
					"Night %d: %d Walkers, %d people, Station 4 at %d HP"
					% [clock.day, world.horde.queued, world.safety.people.size(), post.health]
				)
			)
		world.horde._process(step)
		if world._dirty:
			world._build_now()
		world.zombies._process(step)
		if clock.day != previous_day:
			previous_day = clock.day
			first_wave = false
			print(
				(
					"Dawn %d: %d people, %d food, %d water"
					% [
						clock.day,
						world.safety.people.size(),
						stock.get_amount(&"food"),
						stock.get_amount(&"water")
					]
				)
			)
	print(
		(
			"Opening ended on day %d. Horde nights encountered: %d. %s"
			% [
				clock.day,
				waves,
				main.get_node("GameOver/%Message").text if clock.ended else "Station 4 held."
			]
		)
	)
	quit(0 if clock.day == 6 and not clock.ended else 1)
