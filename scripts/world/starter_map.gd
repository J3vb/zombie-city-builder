class_name StarterMap
extends RefCounted
## Fills a TileMapLayer from a MapDef: ground, border ring, water and rubble.

const SOURCE_ID := 0
const GROUND := Vector2i(0, 0)
const RUBBLE := Vector2i(1, 0)
const WATER := Vector2i(2, 0)
const BORDER := Vector2i(3, 0)


static func generate(layer: TileMapLayer, def: MapDef) -> void:
	layer.clear()
	for y in def.size.y:
		for x in def.size.x:
			layer.set_cell(Vector2i(x, y), SOURCE_ID, _tile_for(Vector2i(x, y), def))


static func _tile_for(cell: Vector2i, def: MapDef) -> Vector2i:
	var b := def.border_width
	if cell.x < b or cell.y < b or cell.x >= def.size.x - b or cell.y >= def.size.y - b:
		return BORDER
	for rect in def.water_rects:
		if rect.has_point(cell):
			return WATER
	for rect in def.rubble_rects:
		if rect.has_point(cell):
			return RUBBLE
	return GROUND
