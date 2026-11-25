extends SceneTree
## Same seed and normal nights for both strategies. Pass -- undefended for the pre-defense opening.

var world: Node
var clock: Node
var stock: Node
var posts: Array[Node] = []
var last_watch := 0
var yard: Node
var shop: Node


func _initialize() -> void:
	call_deferred("_run")


func _street() -> bool:
	var entry: Vector2 = world.roads.entrance
	var tile: float = world.grid.tile_size
	if world.roads.add_road(PackedVector2Array([entry, entry + Vector2.DOWN * tile * 24])) == null:
		return false
	for row in 5:
		for side: int in [-1, 1]:
			if row == 4 and side == 1:
				break
			var cursor := entry + Vector2(side * 8, (3 + row * 4) * tile)
			if world.plots.reserve(cursor, world.plots.rules.plot_frontage) == null:
				return false
	return true


func _order(id: String, cell: Vector2i) -> Node:
	var def := load("res://data/buildings/%s.tres" % id)
	var site: Node = world.try_place_building(def, cell)
	if site == null:
		push_error("Could not order %s at %s" % [id, cell])
	return site


func _build(defended: bool) -> bool:
	if not _street():
		return false
	if defended:
		for cell: Vector2i in [Vector2i(64, 58), Vector2i(60, 65)]:
			var tower := _order("watchtower", cell)
			if tower == null:
				return false
			posts.append(tower)
		var fence := load("res://data/defenses/barricade.tres")
		var gate := load("res://data/defenses/gate.tres")
		if (
			not world.perimeter.order(fence, Vector2i(62, 67), Vector2i(63, 67))
			or not world.perimeter.order(gate, Vector2i(64, 67), Vector2i(65, 67))
			or not world.perimeter.order(fence, Vector2i(66, 67), Vector2i(66, 67))
		):
			return false
	yard = _order("lumber_yard", Vector2i(57, 63) if defended else Vector2i(72, 80))
	if yard == null:
		return false
	if not defended:
		if _order("well", Vector2i(56, 76)) == null:
			return false
		world.grower.paint(Rect2i(55, 70, 3, 3), load("res://data/buildings/farm.tres"))
	return true


func _prepare_watch() -> void:
	if clock.time_of_day < 0.5 or last_watch == clock.day:
		return
	last_watch = clock.day
	for i in mini(posts.size(), world.jobs.residents.size()):
		if is_instance_valid(posts[i]) and not posts[i].is_queued_for_deletion():
			world.jobs.assign(world.jobs.residents[i], posts[i])
	var wave: int = world.horde.horde_size(clock.day)
	while stock.get_amount(&"ammo") < wave:
		if not stock.pack_ammo(world.plots.rules):
			break


func _run() -> void:
	var main := (load("res://scenes/main/main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	current_scene = main
	world = main.world
	clock = root.get_node("GameClock")
	stock = root.get_node("Economy")
	world.horde.rng.seed = 4
	var defended := not OS.get_cmdline_user_args().has("undefended")
	if not _build(defended):
		push_error("Opening street or paid orders failed")
		quit(1)
		return
	var step: float = 1.0 / world.plots.rules.sim_ticks_per_second
	var post: Node = world.command_post
	var waves := 0
	var major_hordes := 0
	while clock.day < 11 and not clock.ended:
		var previous_day: int = clock.day
		clock._advance(step)
		if defended:
			if world.jobs.residents.size() >= 3:
				world.grower.paused = true
			if clock.day != previous_day and not world.jobs.residents.is_empty():
				world.jobs.assign(world.jobs.residents[0], yard)
				if clock.day == 4:
					shop = _order("scrap_workshop", Vector2i(56, 60))
					if shop == null:
						quit(1)
						return
				if clock.day == 5:
					var third := _order("watchtower", Vector2i(67, 64))
					if third == null:
						quit(1)
						return
					posts.append(third)
				if shop != null and world.jobs.residents.size() > 1:
					world.jobs.assign(world.jobs.residents[1], shop)
			_prepare_watch()
			if clock.is_night() and world.zombies.count() > 0 and stock.get_amount(&"ammo") == 0:
				stock.pack_ammo(world.plots.rules)
		if clock.day != previous_day and clock.day <= 10:
			print(
				(
					"Reserves: %d wood, %d scrap; output %s"
					% [
						stock.get_amount(&"wood"),
						stock.get_amount(&"scrap"),
						world.jobs.last_output
					]
				)
			)
		if world.horde.queued > 0 and waves < clock.day:
			if not world.horde.warning().is_empty():
				major_hordes += 1
				print(world.horde.warning())
			waves = clock.day
			print(
				(
					"Night %d: %d Walkers, %d people, %d ammo"
					% [
						clock.day,
						world.horde.queued,
						world.safety.people.size(),
						stock.get_amount(&"ammo")
					]
				)
			)
		world.horde._process(step)
		if world._dirty:
			world._build_now()
		world.zombies._process(step)
		if clock.day != previous_day:
			print(
				(
					"Dawn %d: %d people, %d food, %d water, %d ammo, Station 4 %d HP"
					% [
						clock.day,
						world.safety.people.size(),
						stock.get_amount(&"food"),
						stock.get_amount(&"water"),
						stock.get_amount(&"ammo"),
						post.health
					]
				)
			)
	var shots := 0
	for tower in posts:
		if is_instance_valid(tower):
			shots += tower.shots
	print(
		(
			"Day %d: %d waves, %d shots, %d remaining Walkers. %s"
			% [
				clock.day,
				waves,
				shots,
				world.zombies.count(),
				main.get_node("GameOver/%Message").text if clock.ended else "Station 4 held."
			]
		)
	)
	quit(0 if clock.day == 11 and waves == 10 and major_hordes == 3 and not clock.ended else 1)
