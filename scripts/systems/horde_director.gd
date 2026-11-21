class_name HordeDirector
extends Node
## Sends a horde every night. Zombies appear just inside the map border.

const WALKER_PATH := "res://data/zombies/walker.tres"

var world: World
var queued: int = 0
var rng := RandomNumberGenerator.new()
var walker: ZombieDef

var _balance: BalanceDef = preload("res://data/balance.tres")
var _spawn_cells: Array[Vector2i] = []


func setup(owner_world: World, seed_value: int) -> void:
	world = owner_world
	walker = load(WALKER_PATH) as ZombieDef
	rng.seed = seed_value
	_spawn_cells = _ring_cells()
	EventBus.night_started.connect(_on_night_started)


func horde_size(day: int) -> int:
	return _balance.horde_base + day * _balance.horde_growth


func queue_spawn(amount: int) -> void:
	queued += amount


func random_spawn_point() -> Vector2:
	var cell := _spawn_cells[rng.randi_range(0, _spawn_cells.size() - 1)]
	var jitter := Vector2(rng.randf_range(-8, 8), rng.randf_range(-8, 8))
	return world.grid.cell_to_world(cell) + jitter


func spawn_cells() -> Array[Vector2i]:
	return _spawn_cells


func _on_night_started(day: int) -> void:
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
