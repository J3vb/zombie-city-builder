class_name Grid
extends Node
## Single source of truth for what stands where and what each tile costs.
## cost[i] = base terrain cost, or BLOCKED where a building stands.

signal changed

const BLOCKED := -1

var size: Vector2i
var base_cost: PackedInt32Array
var cost: PackedInt32Array
var occupant: Dictionary[Vector2i, Node2D] = {}

var _layer: TileMapLayer


func setup(layer: TileMapLayer) -> void:
	_layer = layer
	var rect := layer.get_used_rect()
	size = rect.end
	base_cost.resize(size.x * size.y)
	base_cost.fill(BLOCKED)
	for y in size.y:
		for x in size.x:
			var data := layer.get_cell_tile_data(Vector2i(x, y))
			if data:
				base_cost[y * size.x + x] = data.get_custom_data("cost")
	cost = base_cost.duplicate()
	occupant.clear()


func index(cell: Vector2i) -> int:
	return cell.y * size.x + cell.x


func in_bounds(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.y >= 0 and cell.x < size.x and cell.y < size.y


func get_cost(cell: Vector2i) -> int:
	return cost[index(cell)] if in_bounds(cell) else BLOCKED


func is_free(cells: Array[Vector2i]) -> bool:
	for cell in cells:
		if not in_bounds(cell) or cost[index(cell)] <= 0 or occupant.has(cell):
			return false
	return true


func occupy(cells: Array[Vector2i], building: Node2D) -> void:
	for cell in cells:
		occupant[cell] = building
		cost[index(cell)] = BLOCKED
	changed.emit()


func release(cells: Array[Vector2i]) -> void:
	for cell in cells:
		occupant.erase(cell)
		cost[index(cell)] = base_cost[index(cell)]
	changed.emit()


func building_at(cell: Vector2i) -> Node2D:
	return occupant.get(cell)


func cell_to_world(cell: Vector2i) -> Vector2:
	return _layer.to_global(_layer.map_to_local(cell))


func world_to_cell(pos: Vector2) -> Vector2i:
	return _layer.local_to_map(_layer.to_local(pos))


func world_size() -> Vector2:
	return Vector2(size * _layer.tile_set.tile_size)


static func cells_of(anchor: Vector2i, footprint: Vector2i) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	for y in footprint.y:
		for x in footprint.x:
			cells.append(anchor + Vector2i(x, y))
	return cells
