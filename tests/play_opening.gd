extends SceneTree
## Same seed and normal nights for both strategies. Pass -- undefended to skip extra defenses.

var world: Node
var clock: Node
var stock: Node
var posts: Array[Node] = []
var last_watch := 0
var yard: Node
var shop: Node
var extended := false
var month := false
var month_plan: RefCounted
var decisions := 0
var next_trip := 7
var second_shop: Node
var well: Node


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
	return world.try_place_building(def, cell)


func _defenses() -> bool:
	posts.append(world.perimeter.towers[0])
	if not extended:
		var tower := _order("watchtower", Vector2i(60, 65))
		if tower == null:
			return false
		posts.append(tower)
	var fence := load("res://data/defenses/barricade.tres")
	var gate := load("res://data/defenses/gate.tres")
	return (
		world.perimeter.order(fence, Vector2i(62, 67), Vector2i(63, 67))
		and world.perimeter.order(gate, Vector2i(64, 67), Vector2i(65, 67))
		and world.perimeter.order(fence, Vector2i(66, 67), Vector2i(66, 67))
	)


func _build(defended: bool) -> bool:
	if not _street() or (defended and not _defenses()):
		return false
	yard = _order("lumber_yard", Vector2i(57, 63) if defended else Vector2i(72, 80))
	if yard == null:
		return false
	if extended:
		shop = _order("scrap_workshop", Vector2i(56, 60))
		if shop == null:
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
	if month and clock.day >= 10:
		month_plan.watch(world)
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
	month = OS.get_cmdline_user_args().has("month")
	if month:
		month_plan = load("res://tests/month_settlement.gd").new()
	extended = month or OS.get_cmdline_user_args().has("basin")
	if not _build(defended):
		push_error("Opening street or paid orders failed")
		quit(1)
		return
	var step: float = 1.0 / world.plots.rules.sim_ticks_per_second
	var post: Node = world.command_post
	var waves := 0
	var major_hordes := 0
	var end_day := 31 if month else (16 if extended else 11)
	while clock.day < end_day and not clock.ended:
		var previous_day: int = clock.day
		clock._advance(step)
		if extended:
			if clock.day != previous_day:
				for barrier in world.grid.barriers.values():
					if barrier.def.gate:
						world.perimeter.set_gate(barrier, true)
				if clock.day >= 3:
					_expand_basin()
			_basin()
		if defended:
			if world.jobs.residents.size() >= 4:
				world.grower.paused = true
			if clock.day != previous_day and not world.jobs.residents.is_empty():
				world.jobs.assign(world.jobs.residents[0], yard)
				if clock.day == 4 and not extended:
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
			if month and clock.day != previous_day:
				month_plan.morning(world, posts, yard, well, [shop, second_shop])
			_prepare_watch()
			if clock.is_night() and world.zombies.count() > 0 and stock.get_amount(&"ammo") == 0:
				stock.pack_ammo(world.plots.rules)
		if world.horde.queued > 0 and waves < clock.day:
			if not world.horde.warning().is_empty():
				major_hordes += 1
				print(world.horde.warning())
			waves = clock.day
			print(
				(
					"Night %d: %d Drawn, %d people, %d ammo"
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
		if month and month_plan.due(world):
			if not month_plan.resume(main, self):
				push_error("Month replay could not resume the saved settlement")
				quit(1)
				return
			post = world.command_post
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
			"Day %d: %d waves, %d shots, %d remaining Drawn. %s"
			% [
				clock.day,
				waves,
				shots,
				world.zombies.count(),
				main.get_node("GameOver/%Message").text if clock.ended else "Station 4 held."
			]
		)
	)
	var survived: bool = clock.day == end_day and waves == end_day - 1 and not clock.ended
	print("Major hordes: %d Â· Expedition decisions: %d" % [major_hordes, decisions])
	quit(
		(
			0
			if (
				survived
				and major_hordes == (end_day - 1) / 3
				and (not extended or decisions >= 3)
				and (not month or month_plan.passed(world))
			)
			else 1
		)
	)


func _basin() -> void:
	var trips: Node = world.expeditions
	if trips.phase in [trips.Phase.INBOUND, trips.Phase.ENTERING]:
		for gate in world.grid.barriers.values():
			if gate.def.gate and not gate.opened:
				world.perimeter.set_gate(gate, true)
	if trips.phase == trips.Phase.CHOICE:
		var rescue := decisions != 1
		var choice: String = (
			trips.site.encounter.investigate if rescue else trips.site.encounter.leave
		)
		print("Decision %d at %s: %s" % [decisions + 1, trips.site.title, choice])
		trips.choose(rescue)
		decisions += 1
	elif (
		(not month or decisions < 3)
		and clock.day == next_trip
		and clock.time_of_day < 0.1
		and trips.phase == trips.Phase.IDLE
	):
		var ids: Array[int] = []
		# Keep the watch and the first workshop staffed while the team travels.
		for person in world.jobs.residents.slice(2):
			if person != world.construction.builder and ids.size() < 2:
				ids.append(person.resident_id)
		for segment in world.grid.barriers.values():
			if segment.def.gate:
				world.perimeter.set_gate(segment, true)
		var destination: int = [0, 1, 3][mini(decisions, 2)]
		var result: String = trips.launch(trips.SITES[destination], ids, false)
		if result.is_empty():
			next_trip += 3
			print("Dispatch: %s on day %d" % [trips.site.title, clock.day])


func _expand_basin() -> void:
	var garden_cell := Vector2i(59, 63)
	var garden: Node = world.grid.building_at(garden_cell)
	if garden == null:
		garden = _order("garden", garden_cell)
	if garden != null and world.jobs.residents.size() >= 4:
		world.jobs.assign(world.jobs.residents[3], garden)
	if clock.day == 8 and world.jobs.residents.size() >= 4 and world.jobs.residents[3].home == null:
		for plot in world.plots.plots.values():
			if plot.home == null and stock.can_afford(world.plots.house_def.cost):
				if (
					world.try_place_building(world.plots.house_def, plot.house_cells[0], plot)
					!= null
				):
					break
	if clock.day == 3 and posts.size() == 1:
		var second := _order("watchtower", Vector2i(60, 65))
		if second != null:
			posts.append(second)
	if (
		clock.day >= 6
		and second_shop == null
		and stock.get_amount(&"scrap") >= 16
		and stock.get_amount(&"wood") >= 20
	):
		second_shop = _order("scrap_workshop", Vector2i(57, 58))
	if clock.day >= 4 and second_shop != null and world.jobs.residents.size() >= 3:
		world.jobs.assign(world.jobs.residents[2], second_shop)
	if (
		clock.day >= 8
		and well == null
		and stock.can_afford(load("res://data/buildings/well.tres").cost)
	):
		well = _order("well", Vector2i(61, 59))
	if well != null and world.jobs.residents.size() >= 4:
		world.jobs.assign(world.jobs.residents[3], well)
	if (
		posts.size() == 3
		and clock.day >= 10
		and stock.can_afford(load("res://data/buildings/watchtower.tres").cost)
	):
		var site := _order("watchtower", Vector2i(58, 72))
		if site != null:
			posts.append(site)
