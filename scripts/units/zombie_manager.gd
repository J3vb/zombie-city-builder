class_name ZombieManager
extends Node
## Simulates all zombies in packed arrays and publishes one batch for rendering.
## A row index is only valid inside the current frame: deaths are removed at
## the end of the frame by swapping the last row into the gap.

signal crowd_configured(capacity: int, world_size: Vector2)
signal crowd_updated(
	positions: PackedVector2Array,
	types: PackedByteArray,
	states: PackedByteArray,
	defs: Array[ZombieDef],
	count: int
)

enum State { HORDE, ATTACK, CHASE, INVESTIGATE }

var world: World
var last_update_ms: float = 0.0

var _balance: BalanceDef = preload("res://data/balance.tres")
var _defs: Array[ZombieDef] = []
var _count: int = 0
var _pos := PackedVector2Array()
var _health := PackedInt32Array()
var _type := PackedByteArray()
var _state := PackedByteArray()
var _cooldown := PackedFloat32Array()
var _noise_left := PackedFloat32Array()
var _noise_target := PackedVector2Array()
var _dying := PackedInt32Array()
var _hash := SpatialHash.new()
var _near := PackedInt32Array()
var _civilians: Dictionary[int, Resident] = {}
var _frame: int = 0
var _tile: float = 32.0


func setup(owner_world: World) -> void:
	world = owner_world
	_tile = world.tile_size().x
	var cap := _balance.max_zombies
	_pos.resize(cap)
	_health.resize(cap)
	_type.resize(cap)
	_state.resize(cap)
	_cooldown.resize(cap)
	_noise_left.resize(cap)
	_noise_target.resize(cap)
	_hash.setup(world.grid.world_size(), _tile * 2.0)
	crowd_configured.emit(cap, world.grid.world_size())


func count() -> int:
	return _count


func position_of(index: int) -> Vector2:
	return _pos[index]


func spawn(pos: Vector2, def: ZombieDef) -> bool:
	if _count >= _pos.size():
		return false
	var t := _defs.find(def)
	if t == -1:
		_defs.append(def)
		t = _defs.size() - 1
	_pos[_count] = pos
	_health[_count] = def.health
	_type[_count] = t
	_state[_count] = State.HORDE
	_cooldown[_count] = 0.0
	_noise_left[_count] = 0.0
	_count += 1
	return true


func is_alive(index: int) -> bool:
	return index >= 0 and index < _count and _health[index] > 0


func damage(index: int, amount: int) -> void:
	if index < 0 or index >= _count or _health[index] <= 0:
		return
	_health[index] -= amount
	if _health[index] <= 0:
		_dying.append(index)


func kill(index: int) -> void:
	damage(index, _health[index])


## Called during the crowd update, after the spatial hash has been rebuilt.
func alert(origin: Vector2, radius: float) -> void:
	if radius <= 0.0:
		return
	var n := _hash.query(origin, radius, _near)
	for k in n:
		var i := _near[k]
		if is_alive(i):
			_noise_target[i] = origin
			_noise_left[i] = _balance.investigate_seconds


func has_living_near(center: Vector2, radius: float) -> bool:
	var radius_squared := radius * radius
	for i in _count:
		if _health[i] > 0 and _pos[i].distance_squared_to(center) <= radius_squared:
			return true
	return false


func occupies_cell(cell: Vector2i) -> bool:
	for i in _count:
		if _health[i] > 0 and world.grid.world_to_cell(_pos[i]) == cell:
			return true
	return false


func query(pos: Vector2, radius: float, out: PackedInt32Array) -> int:
	return _hash.query(pos, radius, out)


func _process(delta: float) -> void:
	var start := Time.get_ticks_usec()
	_frame += 1
	var dt := delta * GameClock.speed
	_hash.rebuild(_pos, _count)
	if dt > 0.0:
		for tower in world.perimeter.towers:
			tower.fire_tick(world, dt)
		_step_all(dt)
	_remove_dead()
	crowd_updated.emit(_pos, _type, _state, _defs, _count)
	last_update_ms = (Time.get_ticks_usec() - start) / 1000.0


## A Walker row is used only during this update, before packed-array removals.
func _find_civilians() -> void:
	var radius := _tile * _balance.chase_radius_tiles
	world.safety.threatened = 0
	for person in world.safety.people:
		var point := person.sim_position()
		person.threat_near = false
		var n := _hash.query(point, radius, _near) if _count > 0 else 0
		for k in n:
			var i := _near[k]
			if _health[i] <= 0:
				continue
			person.threat_near = true
			if not person.exposed():
				continue
			var previous: Resident = _civilians.get(i)
			if (
				previous == null
				or (
					_pos[i].distance_squared_to(point)
					< _pos[i].distance_squared_to(previous.sim_position())
				)
			):
				_civilians[i] = person
		if person.threat_near:
			world.safety.threatened += 1


func _step_all(dt: float) -> void:
	_find_civilians()
	var field := world.flow_field
	var grid := world.grid
	var target := world.grid.world_size() / 2.0
	if is_instance_valid(world.command_post) and not world.command_post.is_queued_for_deletion():
		target = world.command_post.sim_center()
	var sep_r := _balance.separation_radius
	var sep_k := _balance.separation_strength
	for i in _count:
		if GameClock.ended:
			break
		if _health[i] <= 0:
			continue
		var def := _defs[_type[i]]
		var p := _pos[i]
		var cell := Vector2i(floori(p.x / _tile), floori(p.y / _tile))
		var victim: Resident = _civilians.get(i)
		var chasing := victim != null and victim.exposed()
		_noise_left[i] = maxf(0, _noise_left[i] - dt)
		var investigating := not chasing and _noise_left[i] > 0
		var dir := field.direction_at(cell)
		if chasing:
			var towards := victim.sim_position() - p
			var reach := def.radius + _balance.resident_radius
			if (
				towards.length_squared() <= reach * reach
				and grid.can_cross_corner(p, victim.sim_position())
			):
				_state[i] = State.ATTACK
				if _can_strike(i, dt, def):
					victim.take_hit(def.civilian_damage)
				continue
			dir = towards.normalized()
		elif investigating:
			var to_sound := _noise_target[i] - p
			if to_sound.length_squared() > def.radius * def.radius:
				dir = to_sound.normalized()
			else:
				_noise_left[i] = 0.0
				investigating = false
		if dir == Vector2.ZERO:
			dir = (target - p).normalized()
		var ahead := p + dir * _tile * 0.5
		var ahead_cell := Vector2i(floori(ahead.x / _tile), floori(ahead.y / _tile))
		var segment: BarrierSegment = grid.barriers.get(ahead_cell)
		if segment != null and segment.blocks():
			_state[i] = State.ATTACK
			if _can_strike(i, dt, def):
				world.perimeter.hit(segment, def.building_damage)
			continue
		var building := grid.building_at(ahead_cell)
		if building:
			_state[i] = State.ATTACK
			if _can_strike(i, dt, def):
				building.take_damage(def.building_damage)
			continue
		_state[i] = (
			State.CHASE if chasing else (State.INVESTIGATE if investigating else State.HORDE)
		)
		_cooldown[i] = maxf(0, _cooldown[i] - dt)
		var velocity := dir * def.speed
		if (i + _frame) % 2 == 0:
			velocity += _separation(i, p, sep_r) * sep_k
		_pos[i] = _move(p, velocity * dt, grid)
	_civilians.clear()


func _can_strike(i: int, dt: float, def: ZombieDef) -> bool:
	_cooldown[i] -= dt
	if _cooldown[i] > 0:
		return false
	_cooldown[i] = def.attack_cooldown
	return true


func _separation(i: int, p: Vector2, radius: float) -> Vector2:
	var push := Vector2.ZERO
	var n := _hash.query(p, radius, _near)
	for k in n:
		var j := _near[k]
		if j == i:
			continue
		var away := p - _pos[j]
		var d := away.length()
		if d > 0.001:
			push += away / d * (1.0 - d / radius)
		else:
			push += Vector2.RIGHT.rotated(i)
	return push


## Moves in steps of at most half a tile and never ends inside a blocked tile.
func _move(p: Vector2, motion: Vector2, grid: Grid) -> Vector2:
	var steps := maxi(1, ceili(motion.length() / (_tile * 0.5)))
	var step := motion / steps
	for s in steps:
		var next := p + step
		if _walkable(next, grid) and grid.can_cross_corner(p, next):
			p = next
		elif _walkable(Vector2(next.x, p.y), grid):
			p.x = next.x
		elif _walkable(Vector2(p.x, next.y), grid):
			p.y = next.y
		else:
			break
	return p


func _walkable(p: Vector2, grid: Grid) -> bool:
	return grid.get_cost(Vector2i(floori(p.x / _tile), floori(p.y / _tile))) > 0


func _remove_dead() -> void:
	if _dying.is_empty():
		return
	_dying.sort()
	for k in range(_dying.size() - 1, -1, -1):
		var i := _dying[k]
		if k < _dying.size() - 1 and _dying[k + 1] == i:
			continue
		var last := _count - 1
		_pos[i] = _pos[last]
		_health[i] = _health[last]
		_type[i] = _type[last]
		_state[i] = _state[last]
		_cooldown[i] = _cooldown[last]
		_noise_left[i] = _noise_left[last]
		_noise_target[i] = _noise_target[last]
		_count -= 1
	_dying.clear()
