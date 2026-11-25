class_name HordeDirector
extends Node
## Small nightly groups and warned major hordes use the passable map edges.

const DIRECTIONS := ["north", "east", "south", "west"]
const WALKER_PATH := "res://data/zombies/walker.tres"

var world: World
var queued: int = 0
var rng := RandomNumberGenerator.new()
var walker: ZombieDef
var roster: Array[ZombieDef] = []
var noise := 0.0
var pressure := 0.0
var warning_day := 0
var approach := -1
var _population := 0
var _recent_loss := false
var _edges: Array[Array] = [[], [], [], []]

var _balance: BalanceDef = preload("res://data/balance.tres")
var _spawn_cells: Array[Vector2i] = []


func setup(owner_world: World, seed_value: int) -> void:
	world = owner_world
	walker = load(WALKER_PATH) as ZombieDef
	roster.append(walker)
	for id in ["runner", "brute", "screamer", "crawler"]:
		roster.append(load("res://data/zombies/%s.tres" % id) as ZombieDef)
	_population = world.safety.people.size()
	EventBus.day_started.connect(_dawn)
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
	major = maxi(1, roundi(major * (1.0 + pressure)))
	return (
		major
		if day % _balance.major_horde_interval == 0
		else maxi(1, roundi(major * _balance.minor_wave_share))
	)


func _dawn(_day: int) -> void:
	var count := world.safety.people.size()
	_recent_loss = count < _population
	_population = count
	noise *= _balance.noise_daily_decay


func gunshot() -> void:
	noise = minf(_balance.max_horde_pressure, noise + _balance.noise_pressure_per_shot)


func choose_type(day: int) -> ZombieDef:
	if day < roster[1].first_night:
		return walker
	var total := 0
	for kind in roster:
		if day >= kind.first_night:
			total += kind.appearance_weight
	var roll := rng.randi_range(0, total - 1)
	for kind in roster:
		if day >= kind.first_night:
			roll -= kind.appearance_weight
			if roll < 0:
				return kind
	return walker


func _forecast(day: int) -> void:
	if warning_day == day:
		return
	approach = -1
	if day > _balance.adaptive_after_day:
		var surplus := maxi(0, world.safety.people.size() - _balance.pressure_population_threshold)
		pressure = clampf(
			(
				surplus * _balance.pressure_per_resident
				+ noise
				- (_balance.loss_relief if _recent_loss else 0.0)
			),
			-_balance.loss_relief,
			_balance.max_horde_pressure
		)
	if day % _balance.major_horde_interval == 0:
		var available := PackedInt32Array()
		for side in _edges.size():
			if not _edges[side].is_empty():
				available.append(side)
		if not available.is_empty():
			approach = available[rng.randi_range(0, available.size() - 1)]
			AudioManager.effect("warning")
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
		if not world.zombies.spawn(random_spawn_point(), choose_type(GameClock.day)):
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
