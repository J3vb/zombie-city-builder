class_name HordeDirector
extends Node
## Small nightly groups and warned major hordes use the passable map edges.

const DIRECTIONS := ["north", "east", "south", "west"]
const WALKER_PATH := "res://data/zombies/walker.tres"

var world: World
var queued: int = 0
var rng := RandomNumberGenerator.new()
var walker: ZombieDef
var warning_day := 0
var approach := -1
var _edges: Array[Array] = [[], [], [], []]

var _balance: BalanceDef = preload("res://data/balance.tres")
var _spawn_cells: Array[Vector2i] = []


func setup(owner_world: World, seed_value: int) -> void:
	world = owner_world
	walker = load(WALKER_PATH) as ZombieDef
	rng.seed = seed_value
	_spawn_cells = _ring_cells()
	for cell in _spawn_cells:
		var border := world.map_def.border_width
		if cell.y == border:
			_edges[0].append(cell)
		if cell.x == world.grid.size.x - border - 1:
			_edges[1].append(cell)
		if cell.y == world.grid.size.y - border - 1:
			_edges[2].append(cell)
		if cell.x == border:
			_edges[3].append(cell)
	EventBus.dusk_started.connect(_forecast)
	EventBus.night_started.connect(_on_night_started)


func horde_size(day: int) -> int:
	var major := _balance.horde_base + day * _balance.horde_growth
	return (
		major
		if day % _balance.major_horde_interval == 0
		else maxi(1, roundi(major * _balance.minor_wave_share))
	)


func _forecast(day: int) -> void:
	if warning_day == day:
		return
	approach = -1
	if day % _balance.major_horde_interval == 0:
		var available := PackedInt32Array()
		for side in _edges.size():
			if not _edges[side].is_empty():
				available.append(side)
		if not available.is_empty():
			approach = available[rng.randi_range(0, available.size() - 1)]
	warning_day = day


func warning() -> String:
	if approach < 0 or warning_day != GameClock.day:
		return ""
	return "Major horde from the %s" % DIRECTIONS[approach]


func queue_spawn(amount: int) -> void:
	queued += amount


func random_spawn_point() -> Vector2:
	var cells: Array = (
		_edges[approach] if approach >= 0 and warning_day == GameClock.day else _spawn_cells
	)
	var cell: Vector2i = cells[rng.randi_range(0, cells.size() - 1)]
	var jitter := Vector2(rng.randf_range(-8, 8), rng.randf_range(-8, 8))
	return world.grid.cell_to_world(cell) + jitter


func spawn_cells() -> Array[Vector2i]:
	return _spawn_cells


func _on_night_started(day: int) -> void:
	_forecast(day)
	queue_spawn(horde_size(day))


func _process(_delta: float) -> void:
	if queued <= 0 or _spawn_cells.is_empty() or GameClock.speed == 0:
		return
	var batch := mini(queued, _balance.spawns_per_frame)
	for i in batch:
		if not world.zombies.spawn(random_spawn_point(), walker):
			queued = 0
			return
	queued -= batch


func _ring_cells() -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	var b := world.map_def.border_width
	var size := world.grid.size
	for y in range(b, size.y - b):
		for x in range(b, size.x - b):
			var on_ring := x == b or y == b or x == size.x - 1 - b or y == size.y - 1 - b
			if on_ring and world.grid.get_cost(Vector2i(x, y)) > 0:
				cells.append(Vector2i(x, y))
	return cells
