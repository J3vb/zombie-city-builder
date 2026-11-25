class_name TerrainDressing
extends RefCounted
## Seeded scenery on the blocked map edge and low debris in the mill ruins.


static func build(parent: Node3D, grid: Grid, tile: float, seed_value: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value + 73
	var stone: Array[Transform3D] = []
	var trunks: Array[Transform3D] = []
	var leaves: Array[Transform3D] = []
	for y in grid.size.y:
		for x in grid.size.x:
			var kind := grid.terrain_types[y * grid.size.x + x]
			if kind != TerrainSet.Kind.RUBBLE and kind != TerrainSet.Kind.BORDER:
				continue
			if rng.randf() > (0.38 if kind == TerrainSet.Kind.RUBBLE else 0.65):
				continue
			var point := (
				Vector3(x + rng.randf_range(0.25, 0.75), 0, y + rng.randf_range(0.25, 0.75)) * tile
			)
			var turn := Basis(Vector3.UP, rng.randf_range(0, TAU))
			var scale := rng.randf_range(0.65, 1.25)
			if kind == TerrainSet.Kind.RUBBLE:
				var size := Vector3(1.25, 0.35, 0.70) * scale
				stone.append(Transform3D(turn.scaled(size), point + Vector3.UP * size.y * 0.5))
			else:
				trunks.append(
					Transform3D(
						turn.scaled(Vector3(0.42, 2.5, 0.42) * scale),
						point + Vector3.UP * 1.25 * scale
					)
				)
				for h in [2.2, 3.35]:
					var width := (2.8 if h < 3 else 2.1) * scale
					leaves.append(
						Transform3D(
							turn.scaled(Vector3(width, 3.15 * scale, width)),
							point + Vector3.UP * float(h) * scale
						)
					)
	var rock := BoxMesh.new()
	var trunk := CylinderMesh.new()
	trunk.height = 1
	trunk.top_radius = 0.36
	trunk.bottom_radius = 0.5
	trunk.radial_segments = 6
	var pine := CylinderMesh.new()
	pine.height = 1
	pine.top_radius = 0
	pine.bottom_radius = 0.5
	pine.radial_segments = 7
	_batch(parent, rock, stone, Color("#756957"))
	_batch(parent, trunk, trunks, Color("#635641"))
	_batch(parent, pine, leaves, Color("#42574c"))


static func _batch(
	parent: Node3D, mesh: PrimitiveMesh, placements: Array[Transform3D], color: Color
) -> void:
	if placements.is_empty():
		return
	var paint := StandardMaterial3D.new()
	paint.albedo_color = color
	paint.roughness = 1
	mesh.material = paint
	var batch := MultiMeshInstance3D.new()
	batch.multimesh = MultiMesh.new()
	batch.multimesh.transform_format = MultiMesh.TRANSFORM_3D
	batch.multimesh.mesh = mesh
	batch.multimesh.instance_count = placements.size()
	for i in placements.size():
		batch.multimesh.set_instance_transform(i, placements[i])
	parent.add_child(batch)
