extends RefCounted
## Player orders for the second half of the 30-day balance replay.

var resumed := 0
var farm: Building
var second_field: Building
var third_shop: Building
var extra_post: Building
var north_post: Building


func _order(w: World, id: String, start: Vector2i) -> Building:
	var def := load("res://data/buildings/%s.tres" % id) as BuildingDef
	if (
		not Economy.can_afford(def.cost)
		or (def.cost.has(&"scrap") and Economy.get_amount(&"scrap") - def.cost[&"scrap"] < 4)
	):
		return null
	for reach in range(5):
		for y in range(-reach, reach + 1):
			for x in range(-reach, reach + 1):
				var cell := start + Vector2i(x, y)
				if w.can_place_building(def, cell):
					return w.try_place_building(def, cell)
	return null


func morning(w: World, posts: Array[Node], yard: Building, well: Building, shops: Array) -> void:
	if GameClock.day < 7:
		return
	if GameClock.day >= 8:
		for site: Building in shops:
			if is_instance_valid(site) and site.upgrade_blocker().is_empty():
				site.upgrade()
	if GameClock.day < 10:
		return
	if not is_instance_valid(extra_post) or extra_post.is_queued_for_deletion():
		extra_post = _order(w, "rifle_tower", Vector2i(68, 65))
		if extra_post != null:
			posts.append(extra_post)
	if (
		GameClock.day >= 12
		and (not is_instance_valid(north_post) or north_post.is_queued_for_deletion())
	):
		north_post = _order(w, "rifle_tower", Vector2i(61, 61))
		if north_post != null:
			posts.append(north_post)
	if not is_instance_valid(farm):
		farm = _order(w, "farm", Vector2i(55, 68))
	for plot: FrontagePlot in w.plots.plots.values():
		if (
			plot.home == null
			and w.construction.projects.size() < 2
			and Economy.can_afford(w.plots.house_def.cost)
		):
			w.try_place_building(w.plots.house_def, plot.house_cells[0], plot)
			break
	if GameClock.day >= 15 and farm != null and farm.upgrade_blocker().is_empty():
		farm.upgrade()
	if GameClock.day >= 16 and w.jobs.residents.size() >= 6:
		if not is_instance_valid(second_field):
			second_field = _order(w, "farm", Vector2i(51, 73))
		if not is_instance_valid(third_shop):
			third_shop = _order(w, "scrap_workshop", Vector2i(59, 57))
	var shifts: Array = [shops[0], yard, well, farm, shops[1], third_shop, second_field]
	var people: Array[Resident] = []
	for person in w.jobs.residents:
		if not person.unavailable() and person.home != null and person != w.construction.builder:
			people.append(person)
	for site: Building in shifts:
		if is_instance_valid(site) and site.target_level == 0 and not people.is_empty():
			if w.jobs.assign(people[0], site):
				people.pop_front()


func watch(w: World) -> void:
	var crew: Array[Resident] = []
	var posts := w.perimeter.towers.duplicate()
	posts.sort_custom(
		func(a: DefenseTower, b: DefenseTower) -> bool:
			return (a.def as TowerDef).range_tiles > (b.def as TowerDef).range_tiles
	)
	for person in w.jobs.residents:
		if person != w.construction.builder and person.home != null and not person.unavailable():
			crew.append(person)
	for post: DefenseTower in posts:
		if post.target_level != 0:
			continue
		for person: Resident in crew:
			if w.jobs.assign(person, post):
				crew.erase(person)
				break


func due(w: World) -> bool:
	return (
		(resumed == 0 and GameClock.day == 16)
		or (resumed == 1 and GameClock.day == 24 and w.zombies.count() >= 4)
	)


func resume(main: Main, runner: SceneTree) -> bool:
	var w := main.world
	var references := {}
	for field: String in [
		"yard",
		"shop",
		"second_shop",
		"well",
		"farm",
		"second_field",
		"third_shop",
		"extra_post",
		"north_post"
	]:
		var holder: Object = runner if field in ["yard", "shop", "second_shop", "well"] else self
		var building := holder.get(field) as Building
		if is_instance_valid(building) and not building.is_queued_for_deletion():
			references[field] = building.cell
	var cells: Array[Vector2i] = []
	for tower in runner.get("posts"):
		if is_instance_valid(tower) and not tower.is_queued_for_deletion():
			cells.append(tower.cell)
	var total := w.zombies.count()
	var people := w.safety.people.size()
	var rng_state := w.horde.rng.state
	var directory := SaveManager.directory
	SaveManager.directory = "user://month-replay"
	var ok := SaveManager.write_slot(main, 1) and main.restore_game(SaveManager.read_slot(1))
	SaveManager.directory = directory
	if not ok:
		return false
	w = main.world
	runner.set("world", w)
	for field: String in references:
		var holder: Object = runner if field in ["yard", "shop", "second_shop", "well"] else self
		holder.set(field, w.grid.building_at(references[field]))
	var posts: Array[Node] = []
	for cell in cells:
		posts.append(w.grid.building_at(cell))
	runner.set("posts", posts)
	resumed += 1
	print("Resumed day %d with %d residents and %d active Drawn." % [GameClock.day, people, total])
	return (
		w.zombies.count() == total
		and w.safety.people.size() == people
		and w.horde.rng.state == rng_state
	)


func passed(w: World) -> bool:
	return (
		resumed == 2
		and w.safety.people.size() > 0
		and w.command_post.health > 0
		and w.zombies.count() == 0
		and Economy.get_amount(&"food") > 0
		and Economy.get_amount(&"water") > 0
	)
