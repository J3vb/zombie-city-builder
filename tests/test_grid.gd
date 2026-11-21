extends TestCase

const TILESET := preload("res://assets/tiles/terrain_tileset.tres")

var _layer: TileMapLayer
var _grid: Grid
var _changes: int = 0


func _setup() -> void:
	var map := MapDef.new()
	map.size = Vector2i(8, 6)
	map.water_rects = [Rect2i(5, 2, 2, 2)]
	map.rubble_rects = [Rect2i(1, 1, 1, 1)]
	_layer = TileMapLayer.new()
	_layer.tile_set = TILESET
	StarterMap.generate(_layer, map)
	_grid = Grid.new()
	_grid.setup(_layer)
	_grid.changed.connect(func() -> void: _changes += 1)


func _teardown() -> void:
	_grid.free()
	_layer.free()


func test_setup_reads_terrain_costs() -> void:
	_setup()
	assert_eq(_grid.size, Vector2i(8, 6), "size")
	assert_eq(_grid.get_cost(Vector2i(0, 0)), Grid.BLOCKED, "border")
	assert_eq(_grid.get_cost(Vector2i(1, 1)), 3, "rubble")
	assert_eq(_grid.get_cost(Vector2i(2, 2)), 1, "ground")
	assert_eq(_grid.get_cost(Vector2i(5, 2)), Grid.BLOCKED, "water")
	_teardown()


func test_occupy_and_release() -> void:
	_setup()
	var cells := Grid.cells_of(Vector2i(2, 2), Vector2i(2, 2))
	var house := Node2D.new()
	assert_true(_grid.is_free(cells), "free before")
	_grid.occupy(cells, house)
	assert_true(not _grid.is_free(cells), "not free after occupy")
	assert_eq(_grid.get_cost(Vector2i(3, 3)), Grid.BLOCKED, "occupied cost")
	assert_eq(_grid.building_at(Vector2i(3, 3)), house, "building_at")
	_grid.release(cells)
	assert_true(_grid.is_free(cells), "free after release")
	assert_eq(_grid.get_cost(Vector2i(3, 3)), 1, "cost restored")
	assert_eq(_changes, 2, "changed fires once per call")
	house.free()
	_teardown()


func test_out_of_bounds_and_blocked_not_free() -> void:
	_setup()
	var outside: Array[Vector2i] = [Vector2i(-1, 2)]
	var on_water: Array[Vector2i] = [Vector2i(5, 3)]
	var on_border: Array[Vector2i] = [Vector2i(0, 3)]
	assert_true(not _grid.is_free(outside), "outside")
	assert_true(not _grid.is_free(on_water), "water")
	assert_true(not _grid.is_free(on_border), "border")
	_teardown()
