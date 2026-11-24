extends TestCase

const TERRAIN_SET_PATH := "res://data/terrain/terrain_set.tres"

var _grid: Grid
var _changes: int = 0


func _setup() -> void:
	var map := MapDef.new()
	map.size = Vector2i(8, 6)
	map.water_rects = [Rect2i(5, 2, 2, 2)]
	map.rubble_rects = [Rect2i(1, 1, 1, 1)]
	_grid = Grid.new()
	_grid.setup(map, StarterMap.generate(map), load(TERRAIN_SET_PATH) as TerrainSet)
	_grid.changed.connect(func() -> void: _changes += 1)


func _teardown() -> void:
	_grid.free()


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


func test_coordinates_use_simulation_tile_size() -> void:
	var map := MapDef.new()
	map.size = Vector2i(6, 4)
	map.tile_size = 10
	var grid := Grid.new()
	grid.setup(map, StarterMap.generate(map), load(TERRAIN_SET_PATH) as TerrainSet)
	assert_eq(grid.world_size(), Vector2(60, 40), "size in simulation units")
	assert_eq(grid.cell_to_world(Vector2i(2, 3)), Vector2(25, 35), "center")
	assert_eq(grid.world_to_cell(Vector2(19.99, 5)), Vector2i(1, 0), "before tile edge")
	assert_eq(grid.world_to_cell(Vector2(20, 5)), Vector2i(2, 0), "on tile edge")
	assert_eq(grid.world_to_cell(Vector2(-0.1, 1)), Vector2i(-1, 0), "outside left")
	grid.free()


func test_border_and_water_take_precedence_over_rubble() -> void:
	var map := MapDef.new()
	map.size = Vector2i(4, 3)
	map.water_rects = [Rect2i(0, 0, 2, 2)]
	map.rubble_rects = [Rect2i(0, 0, 3, 2)]
	var ids := StarterMap.generate(map)
	assert_eq(ids.size(), 12, "one ID per cell")
	assert_eq(ids[4], TerrainSet.Kind.BORDER, "border covers water and rubble")
	assert_eq(ids[5], TerrainSet.Kind.WATER, "water covers rubble")
	assert_eq(ids[6], TerrainSet.Kind.RUBBLE, "rubble remains visible outside water")
