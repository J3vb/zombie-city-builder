extends MultiMeshInstance2D
## Uploads the Walker poses and colors to the 2D crowd mesh once per frame.

const FLOATS_PER_INSTANCE := 12
const ATTACK_TINT := Color(1.0, 0.55, 0.45)

var _buffer := PackedFloat32Array()


func setup(capacity: int, world_size: Vector2) -> void:
	_buffer.resize(capacity * FLOATS_PER_INSTANCE)
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_2D
	mm.use_colors = true
	var quad := QuadMesh.new()
	quad.size = Vector2(1, 1)
	mm.mesh = quad
	mm.instance_count = capacity
	mm.visible_instance_count = 0
	# The buffer is written directly, so Godot can't work out the bounds itself.
	mm.custom_aabb = AABB(Vector3(-64, -64, -1), Vector3(world_size.x + 128, world_size.y + 128, 2))
	multimesh = mm


func present(
	positions: PackedVector2Array,
	types: PackedByteArray,
	states: PackedByteArray,
	defs: Array[ZombieDef],
	count: int
) -> void:
	multimesh.visible_instance_count = count
	if count == 0:
		return
	for i in count:
		var def := defs[types[i]]
		var size := def.radius * 2.0
		var c := def.color * ATTACK_TINT if states[i] == ZombieManager.State.ATTACK else def.color
		var o := i * FLOATS_PER_INSTANCE
		_buffer[o] = size
		_buffer[o + 1] = 0.0
		_buffer[o + 2] = 0.0
		_buffer[o + 3] = positions[i].x
		_buffer[o + 4] = 0.0
		_buffer[o + 5] = size
		_buffer[o + 6] = 0.0
		_buffer[o + 7] = positions[i].y
		_buffer[o + 8] = c.r
		_buffer[o + 9] = c.g
		_buffer[o + 10] = c.b
		_buffer[o + 11] = 1.0
	RenderingServer.multimesh_set_buffer(multimesh.get_rid(), _buffer)
