extends Node
## Peaceful economic playtest with ten people, finished workplaces and normal shifts and upkeep.


func _ready() -> void:
	var world: World = $Main.world
	world.grower.paused = true
	world.horde.set_process(false)
	var start := world.roads.entrance
	var tile := world.grid.tile_size
	var street := world.roads.add_road(
		PackedVector2Array([start, start + Vector2.DOWN * tile * 24])
	)
	if street == null:
		push_error("Supply town could not draw its street")
		return
	for row in 5:
		for side: int in [-1, 1]:
			if world.jobs.residents.size() == 9:
				break
			var cursor := start + Vector2(side * 8, (3 + 4 * row) * tile)
			var plot := world.plots.reserve(cursor, world.plots.rules.plot_frontage)
			if (
				plot == null
				or world.spawn_building(world.plots.house_def, plot.house_cells[0], plot) == null
			):
				push_error("Supply town could not set up its homes")
				return
	var works: Dictionary[Vector2i, String] = {
		Vector2i(55, 70): "farm",
		Vector2i(72, 74): "farm",
		Vector2i(56, 76): "well",
		Vector2i(72, 80): "lumber_yard",
		Vector2i(56, 82): "scrap_workshop"
	}
	for cell in works:
		var def := load("res://data/buildings/%s.tres" % works[cell]) as BuildingDef
		if world.spawn_building(def, cell) == null:
			push_error("Supply town could not place its %s" % def.display_name)
			return
	var stock := world.plots.rules.start_resources.duplicate()
	stock[&"food"] = 10
	stock[&"water"] = 0
	stock[&"wood"] = 0
	stock[&"scrap"] = 0
	Economy.reset(stock)
	world.camera.position = world.to_view(world.grid.cell_to_world(Vector2i(64, 77)))
	world.camera.distance = 115
	world.camera.rotation.y = 0.25
	world.camera._apply()
