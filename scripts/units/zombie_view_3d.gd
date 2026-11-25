extends MultiMeshInstance3D
## Uploads all five Drawn silhouettes to one animated mesh after the simulation finishes a frame.

const STRIDE := 20
const POSES := {&"walker": 0, &"runner": 1, &"brute": 2, &"screamer": 3, &"crawler": 4}
const HEIGHT := 1.8
const ATTACK_TINT := Color(1.0, 0.55, 0.45)

var _buffer := PackedFloat32Array()
var _scale: float
var _clock := 0.0
var _material := ShaderMaterial.new()
var _previous := PackedVector2Array()
var _facing := PackedVector2Array()


func setup(capacity: int, world_size: Vector2) -> void:
	var manager := get_parent() as ZombieManager
	_scale = manager.world.map_def.view_scale
	_material.shader = load("res://assets/materials/drawn.gdshader")
	material_override = _material
	_previous.resize(capacity)
	_facing.resize(capacity)
	_facing.fill(Vector2.DOWN)
	multimesh = MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.use_colors = true
	multimesh.use_custom_data = true
	multimesh.mesh = load("res://scenes/models/drawn.obj") as Mesh
	multimesh.instance_count = capacity
	multimesh.visible_instance_count = 0
	multimesh.custom_aabb = AABB(
		Vector3(-2, -1, -2),
		Vector3(world_size.x * _scale + 4, HEIGHT + 2, world_size.y * _scale + 4)
	)
	_buffer.resize(capacity * STRIDE)


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
	_clock += get_process_delta_time() * GameClock.speed
	_material.set_shader_parameter("stride_clock", _clock)
	for i in count:
		var def := defs[types[i]]
		var diameter := def.radius * 1.05 * _scale
		var color := (
			def.color * ATTACK_TINT if states[i] == ZombieManager.State.ATTACK else def.color
		)
		var motion := positions[i] - _previous[i]
		if motion.length_squared() > 0.000001:
			_facing[i] = motion.normalized()
		_previous[i] = positions[i]
		var direction := _facing[i]
		var o := i * STRIDE
		_buffer[o] = direction.y * diameter
		_buffer[o + 2] = direction.x * diameter
		_buffer[o + 3] = positions[i].x * _scale
		_buffer[o + 5] = 1.0 if def.crawl_under else def.height_scale
		_buffer[o + 8] = -direction.x * diameter
		_buffer[o + 10] = direction.y * diameter
		_buffer[o + 11] = positions[i].y * _scale
		_buffer[o + 12] = color.r
		_buffer[o + 13] = color.g
		_buffer[o + 14] = color.b
		_buffer[o + 15] = 1.0
		_buffer[o + 16] = float(POSES.get(def.id, 0)) / 4.0
		_buffer[o + 17] = fmod(i * 2.4, TAU) / TAU
	RenderingServer.multimesh_set_buffer(multimesh.get_rid(), _buffer)
