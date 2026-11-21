class_name ZombieManager
extends Node2D
## All zombies as rows in packed arrays, drawn in one MultiMesh.
## A row index is only valid inside the current frame: deaths are removed at
## the end of the frame by swapping the last row into the gap.

enum State { HORDE, ATTACK }

const FLOATS_PER_INSTANCE := 12
const ATTACK_TINT := Color(1.0, 0.55, 0.45)

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
var _dying := PackedInt32Array()
var _hash := SpatialHash.new()
var _near := PackedInt32Array()
var _buffer := PackedFloat32Array()
var _frame: int = 0
var _tile: float = 32.0

@onready var _mesh_instance: MultiMeshInstance2D = $Mesh


func setup(owner_world: World) -> void:
	world = owner_world
	_tile = world.tile_size().x
	var cap := _balance.max_zombies
	_pos.resize(cap)
	_health.resize(cap)
	_type.resize(cap)
	_state.resize(cap)
	_cooldown.resize(cap)
	_buffer.resize(cap * FLOATS_PER_INSTANCE)
	_hash.setup(world.grid.world_size(), _tile * 2.0)
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_2D
	mm.use_colors = true
	var quad := QuadMesh.new()
	quad.size = Vector2(1, 1)
	mm.mesh = quad
	mm.instance_count = cap
	mm.visible_instance_count = 0
	# The buffer is written directly, so Godot can't work out the bounds itself.
	var world_size := world.grid.world_size()
	mm.custom_aabb = AABB(Vector3(-64, -64, -1), Vector3(world_size.x + 128, world_size.y + 128, 2))
	_mesh_instance.multimesh = mm


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
	_count += 1
	return true


func damage(index: int, amount: int) -> void:
	if index < 0 or index >= _count or _health[index] <= 0:
		return
	_health[index] -= amount
	if _health[index] <= 0:
		_dying.append(index)


func kill(index: int) -> void:
	damage(index, _health[index])


func query(pos: Vector2, radius: float, out: PackedInt32Array) -> int:
	return _hash.query(pos, radius, out)


func _process(delta: float) -> void:
	var start := Time.get_ticks_usec()
	_frame += 1
	var dt := delta * GameClock.speed
	_hash.rebuild(_pos, _count)
	if dt > 0.0:
		_step_all(dt)
	_remove_dead()
	_upload()
	last_update_ms = (Time.get_ticks_usec() - start) / 1000.0


func _step_all(dt: float) -> void:
	var field := world.flow_field
	var grid := world.grid
	var target := world.grid.world_size() / 2.0
	if is_instance_valid(world.command_post):
		target = world.command_post.global_position
	var sep_r := _balance.separation_radius
	var sep_k := _balance.separation_strength
	for i in _count:
		if _health[i] <= 0:
			continue
		var def := _defs[_type[i]]
		var p := _pos[i]
		var cell := Vector2i(floori(p.x / _tile), floori(p.y / _tile))
		var dir := field.direction_at(cell)
		if dir == Vector2.ZERO:
			dir = (target - p).normalized()
		var ahead := p + dir * _tile * 0.5
		var ahead_cell := Vector2i(floori(ahead.x / _tile), floori(ahead.y / _tile))
		var building := grid.building_at(ahead_cell) as Building
		if building:
			_state[i] = State.ATTACK
			_cooldown[i] -= dt
			if _cooldown[i] <= 0.0:
				_cooldown[i] = def.attack_cooldown
				building.take_damage(def.building_damage)
			continue
		_state[i] = State.HORDE
		var velocity := dir * def.speed
		if (i + _frame) % 2 == 0:
			velocity += _separation(i, p, sep_r) * sep_k
		_pos[i] = _move(p, velocity * dt, grid)


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
		if _walkable(next, grid):
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
		_count -= 1
	_dying.clear()


func _upload() -> void:
	var mm := _mesh_instance.multimesh
	for i in _count:
		var def := _defs[_type[i]]
		var size := def.radius * 2.0
		var c := def.color * ATTACK_TINT if _state[i] == State.ATTACK else def.color
		var o := i * FLOATS_PER_INSTANCE
		_buffer[o] = size
		_buffer[o + 1] = 0.0
		_buffer[o + 2] = 0.0
		_buffer[o + 3] = _pos[i].x
		_buffer[o + 4] = 0.0
		_buffer[o + 5] = size
		_buffer[o + 6] = 0.0
		_buffer[o + 7] = _pos[i].y
		_buffer[o + 8] = c.r
		_buffer[o + 9] = c.g
		_buffer[o + 10] = c.b
		_buffer[o + 11] = 1.0
	RenderingServer.multimesh_set_buffer(mm.get_rid(), _buffer)
	mm.visible_instance_count = _count
