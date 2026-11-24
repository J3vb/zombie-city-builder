class_name Grid
extends Node
## Single source of truth for what stands where and what each tile costs.
## cost[i] = base terrain cost, or BLOCKED where a building stands.

signal changed

const BLOCKED := -1

var size: Vector2i
var tile_size: int
var terrain_types: PackedByteArray
var base_cost: PackedInt32Array
var cost: PackedInt32Array
var road_cells: Dictionary[Vector2i, int] = {}
var occupant: Dictionary[Vector2i, Building] = {}


func setup(map: MapDef, types: PackedByteArray, terrain: TerrainSet) -> void:
	size = map.size
	tile_size = map.tile_size
	terrain_types = types
	base_cost.resize(terrain_types.size())
	for i in terrain_types.size():
		base_cost[i] = terrain.types[terrain_types[i]].cost
	cost = base_cost.duplicate()
	occupant.clear()
	road_cells.clear()


func index(cell: Vector2i) -> int:
	return cell.y * size.x + cell.x


func in_bounds(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.y >= 0 and cell.x < size.x and cell.y < size.y


func get_cost(cell: Vector2i) -> int:
	return cost[index(cell)] if in_bounds(cell) else BLOCKED


func is_free(cells: Array[Vector2i]) -> bool:
	for cell in cells:
		if (
			not in_bounds(cell)
			or cost[index(cell)] <= 0
			or occupant.has(cell)
			or road_cells.has(cell)
		):
			return false
	return true


## Shared junction cells remain reserved until their last street is removed.
func mark_road(cells: Array[Vector2i], delta: int) -> void:
	for cell in cells:
		var uses: int = road_cells.get(cell, 0) + delta
		if uses > 0:
			road_cells[cell] = uses
			cost[index(cell)] = 1
		else:
			road_cells.erase(cell)
			cost[index(cell)] = base_cost[index(cell)]
	changed.emit()


func occupy(cells: Array[Vector2i], building: Building) -> bool:
	if building == null or cells.is_empty() or not is_free(cells):
		return false
	for cell in cells:
		occupant[cell] = building
		cost[index(cell)] = BLOCKED
	changed.emit()
	return true


func release(cells: Array[Vector2i], owner_building: Building) -> void:
	if owner_building == null:
		return
	var released := false
	for cell in cells:
		if occupant.get(cell) == owner_building:
			occupant.erase(cell)
			cost[index(cell)] = base_cost[index(cell)]
			released = true
	if released:
		changed.emit()


func building_at(cell: Vector2i) -> Building:
	return occupant.get(cell)


func cell_to_world(cell: Vector2i) -> Vector2:
	return (Vector2(cell) + Vector2(0.5, 0.5)) * tile_size


func world_to_cell(pos: Vector2) -> Vector2i:
	return Vector2i((pos / tile_size).floor())


func world_size() -> Vector2:
	return Vector2(size * tile_size)


static func cells_of(anchor: Vector2i, footprint: Vector2i) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	for y in footprint.y:
		for x in footprint.x:
			cells.append(anchor + Vector2i(x, y))
	return cells
