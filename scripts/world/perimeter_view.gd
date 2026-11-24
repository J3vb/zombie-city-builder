class_name PerimeterView
extends Node3D
## Renders all perimeter pieces with one instanced mesh, including open gate posts.

var world: World
var _batch := MultiMeshInstance3D.new()
var _parts: Array[Transform3D] = []
var _colors: Array[Color] = []


func setup(owner_world: World) -> void:
	world = owner_world
	var mesh := BoxMesh.new()
	var material := StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	mesh.material = material
	var batch := MultiMesh.new()
	batch.transform_format = MultiMesh.TRANSFORM_3D
	batch.use_colors = true
	batch.mesh = mesh
	_batch.multimesh = batch
	add_child(_batch)


func _piece(local: Vector3, size: Vector3, origin: Transform3D, color: Color) -> void:
	_parts.append(origin * Transform3D(Basis.from_scale(size), local))
	_colors.append(color)


func redraw() -> void:
	_parts.clear()
	_colors.clear()
	for s: BarrierSegment in world.grid.barriers.values():
		var base := world.to_view(world.grid.cell_to_world(s.cell))
		var frame := Transform3D(Basis(Vector3.UP, PI / 2 if s.along_z else 0.0), base)
		var span := world.view_tile()
		var h := s.def.height if s.complete else 0.5
		var tone := s.def.color
		for side: float in [-1.0, 1.0]:
			_piece(
				Vector3(span * 0.42 * side, h * 0.5, 0),
				Vector3(0.42, h, 0.62),
				frame,
				tone.darkened(0.24)
			)
		if not s.complete or (s.def.gate and s.opened):
			continue
		_piece(Vector3(0, h * 0.48, 0), Vector3(span, h * 0.74, 0.46), frame, tone)
		_piece(Vector3(0, h * 0.83, 0), Vector3(span, 0.18, 0.66), frame, tone.lightened(0.13))
	var batch := _batch.multimesh
	batch.instance_count = _parts.size()
	for i in _parts.size():
		batch.set_instance_transform(i, _parts[i])
		batch.set_instance_color(i, _colors[i])
