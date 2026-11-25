class_name StarterMap
extends RefCounted
## Generates one terrain ID per cell, in row-major order.


static func generate(def: MapDef) -> PackedByteArray:
	var terrain := PackedByteArray()
	terrain.resize(def.size.x * def.size.y)
	for y in def.size.y:
		for x in def.size.x:
			terrain[y * def.size.x + x] = _terrain_at(Vector2i(x, y), def)
	for lake in def.lakes:
		var radius := Vector2(lake.size) * 0.5
		for y in range(lake.position.y, lake.end.y):
			for x in range(lake.position.x, lake.end.x):
				if (
					(
						((Vector2(x + 0.5, y + 0.5) - Vector2(lake.position) - radius) / radius)
						. length_squared()
					)
					< 1.0
				):
					terrain[y * def.size.x + x] = TerrainSet.Kind.WATER
	for highway in def.highways:
		for i in range(1, highway.size()):
			var a := highway[i - 1]
			var b := highway[i]
			var steps := ceili(a.distance_to(b) * 2)
			for j in range(steps + 1):
				var center := Vector2i(a.lerp(b, float(j) / maxi(steps, 1)).round())
				for offset: Vector2i in [Vector2i.ZERO, Vector2i.RIGHT, Vector2i.DOWN]:
					var cell := center + offset
					if Rect2i(Vector2i.ZERO, def.size).has_point(cell):
						var id := cell.y * def.size.x + cell.x
						if terrain[id] == TerrainSet.Kind.GROUND:
							terrain[id] = TerrainSet.Kind.PAVEMENT
	for place in def.places:
		var bounds := place.extent()
		for y in range(bounds.position.y, bounds.end.y):
			for x in range(bounds.position.x, bounds.end.x):
				if (x - bounds.position.x) % 7 == 0 or (y - bounds.position.y) % 7 == 0:
					terrain[y * def.size.x + x] = TerrainSet.Kind.PAVEMENT
		for footprint in place.footprints():
			for y in range(footprint.position.y, footprint.end.y):
				for x in range(footprint.position.x, footprint.end.x):
					terrain[y * def.size.x + x] = TerrainSet.Kind.RUIN
	return terrain


static func _terrain_at(cell: Vector2i, def: MapDef) -> TerrainSet.Kind:
	var b := def.border_width
	if cell.x < b or cell.y < b or cell.x >= def.size.x - b or cell.y >= def.size.y - b:
		return TerrainSet.Kind.BORDER
	for rect in def.water_rects:
		if rect.has_point(cell):
			return TerrainSet.Kind.WATER
	for rect in def.rubble_rects:
		if rect.has_point(cell):
			return TerrainSet.Kind.RUBBLE
	return TerrainSet.Kind.GROUND
