class_name RestoreGround
extends RefCounted
## Rebuilds the saved street, parcel, building and barrier claims on a fresh grid.
# Validation exits on the first invalid field.
# gdlint: disable=max-returns

var codec := SaveValues.new()


func _roads(w: World, records: Array) -> bool:
	var seen := {}
	for raw: Variant in records:
		if not raw is Dictionary or not _positive_id(raw.get("id")):
			return false
		var id := int(raw.id)
		var points: Variant = codec.decode(raw.get("points"))
		if (
			seen.has(id)
			or not points is PackedVector2Array
			or points.size() < 2
			or points.size() > 4096
		):
			return false
		for point: Vector2 in points:
			if not point.is_finite() or not w.grid.in_bounds(w.grid.world_to_cell(point)):
				return false
		w.roads._next_id = id
		var quadratic: Variant = raw.get("quadratic", false)
		if typeof(quadratic) != TYPE_BOOL or w.roads.add_road(points, false, quadratic) == null:
			return false
		seen[id] = true
	return true


func _plots(w: World, records: Array) -> bool:
	for raw: Variant in records:
		var p := FrontagePlot.new()
		if not codec.fill(p, SaveLayout.PLOT, raw):
			return false
		if p.id < 1 or w.plots.plots.has(p.id) or not w.roads.roads.has(p.road_id):
			return false
		if (
			p.polygon.size() != 4
			or p.house.size() != 4
			or p.house_cells.is_empty()
			or not w.grid.in_bounds(p.door)
		):
			return false
		for cell in p.cells:
			if not w.grid.in_bounds(cell) or w.grid.parcel_cells.has(cell):
				return false
			w.grid.parcel_cells[cell] = p.id
			w.grid.cell_edited.emit(cell)
		for cell in p.house_cells:
			if not p.cells.has(cell):
				return false
		w.plots.plots[p.id] = p
		codec.register("plot/%d" % p.id, p)
	return true


func _buildings(w: World, records: Array) -> bool:
	var station := false
	for raw: Variant in records:
		if not raw is Dictionary or not raw.get("state") is Dictionary:
			return false
		var def := codec.objects.get(raw.get("kind", "")) as BuildingDef
		var cell: Variant = codec.decode(raw.get("cell"))
		var plot: Variant = codec.decode(raw.get("plot"))
		if (
			def == null
			or not cell is Vector2i
			or not w.grid.in_bounds(cell)
			or (plot != null and not plot is FrontagePlot)
		):
			return false
		var b: Building
		if def == w.command_post.def:
			if station or cell != w.command_post.cell or plot != null:
				return false
			b = w.command_post
			station = true
		else:
			var unfinished: Variant = codec.decode(raw.state.get("target_level"))
			b = w._place(def, cell, plot, unfinished == 1)
		if b == null or not codec.fill(b, SaveLayout.BUILD, raw.state):
			return false
		if (
			b.level < 1
			or b.level > maxi(1, def.levels.size())
			or b.health < 1
			or b.health > b.max_health()
		):
			return false
		if b.target_level < 0 or b.target_level > maxi(1, def.levels.size()):
			return false
		if b is DefenseTower and not codec.fill(b, SaveLayout.TOWER, raw.get("tower")):
			return false
		b.construction_changed.emit()
		codec.register(SaveLayout.cell_id("building", cell), b)
	return station


func _segments(w: World, records: Array) -> bool:
	for raw: Variant in records:
		if not raw is Dictionary:
			return false
		var cell: Variant = codec.decode(raw.get("cell"))
		var def := codec.objects.get(raw.get("kind", "")) as BarrierDef
		if (
			def == null
			or not cell is Vector2i
			or not w.grid.in_bounds(cell)
			or w.grid.barriers.has(cell)
		):
			return false
		var segment := BarrierSegment.new()
		segment.cell = cell
		segment.def = def
		if not codec.fill(segment, SaveLayout.BARRIER, raw.get("state")):
			return false
		w.grid.barriers[cell] = segment
		w.grid.restore_ground(cell)
		codec.register(SaveLayout.cell_id("segment", cell), segment)
		if raw.has("post"):
			if not segment.complete or def not in [Perimeter.WALL, Perimeter.CHECKPOINT]:
				return false
			var post := DefenseTower.new()
			post.setup(Perimeter.WALL_POST, cell, w.grid)
			w.perimeter.add_child(post)
			segment.post = post
			if not codec.fill(post, SaveLayout.TOWER, raw.post):
				return false
			codec.register(SaveLayout.cell_id("post", cell), post)
	return true


func _positive_id(id: Variant) -> bool:
	return typeof(id) in [TYPE_INT, TYPE_FLOAT] and id == int(id) and id >= 1 and id <= 2147483647
