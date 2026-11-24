class_name StarterMap
extends RefCounted
## Generates one terrain ID per cell, in row-major order.


static func generate(def: MapDef) -> PackedByteArray:
	var terrain := PackedByteArray()
	terrain.resize(def.size.x * def.size.y)
	for y in def.size.y:
		for x in def.size.x:
			terrain[y * def.size.x + x] = _terrain_at(Vector2i(x, y), def)
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
