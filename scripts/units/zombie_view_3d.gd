extends MultiMeshInstance3D
## Uploads all living Walkers to one 3D mesh after the simulation finishes a frame.

const STRIDE := 16
const HEIGHT := 1.8
const ATTACK_TINT := Color(1.0, 0.55, 0.45)

var _buffer := PackedFloat32Array()
var _scale: float


func setup(capacity: int, world_size: Vector2) -> void:
	var manager := get_parent() as ZombieManager
	_scale = manager.world.map_def.view_scale
	var model := CapsuleMesh.new()
	model.radial_segments = 8
	model.rings = 2
	model.radius = 0.5
	model.height = HEIGHT
	var material := StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	model.material = material
	multimesh = MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.use_colors = true
	multimesh.mesh = model
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
	for i in count:
		var def := defs[types[i]]
		var diameter := def.radius * 2.0 * _scale
		var color := (
			def.color * ATTACK_TINT if states[i] == ZombieManager.State.ATTACK else def.color
		)
		var o := i * STRIDE
		_buffer[o] = diameter
		_buffer[o + 3] = positions[i].x * _scale
		_buffer[o + 5] = def.height_scale
		_buffer[o + 7] = HEIGHT * def.height_scale * 0.5
		_buffer[o + 10] = diameter
		_buffer[o + 11] = positions[i].y * _scale
		_buffer[o + 12] = color.r
		_buffer[o + 13] = color.g
		_buffer[o + 14] = color.b
		_buffer[o + 15] = 1.0
	RenderingServer.multimesh_set_buffer(multimesh.get_rid(), _buffer)
