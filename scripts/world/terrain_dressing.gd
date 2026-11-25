class_name TerrainDressing
extends RefCounted
## Seeded scenery on the blocked map edge and low debris in the mill ruins.


static func build(parent: Node3D, grid: Grid, tile: float, seed_value: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value + 73
	var rush: Array[Transform3D] = []
	var shore: Array[Transform3D] = []
	var stone: Array[Transform3D] = []
	var trunks: Array[Transform3D] = []
	var leaves: Array[Transform3D] = []
	for y in grid.size.y:
		for x in grid.size.x:
			var kind := grid.terrain_types[y * grid.size.x + x]
			if (
				kind == TerrainSet.Kind.WATER
				and x > 0
				and y > 0
				and x + 1 < grid.size.x
				and y + 1 < grid.size.y
			):
				var cell := Vector2i(x, y)
				for direction: Vector2i in [
					Vector2i.LEFT, Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN
				]:
					if grid.get_cost(cell + direction) > 0 and rng.randf() < 0.55:
						var point := (
							Vector3(
								x + 0.5 + 0.43 * direction.x, -0.21, y + 0.5 + 0.43 * direction.y
							)
							* Vector3(tile, 1, tile)
						)
						var turn := Basis(Vector3.UP, rng.randf_range(0, TAU))
						rush.append(Transform3D(turn.scaled(Vector3(1.3, 1.5, 1.3)), point))
						if rng.randf() < 0.23:
							shore.append(
								Transform3D(
									turn.scaled(Vector3(1.6, 1.1, 1.9)), point + Vector3.RIGHT * 0.8
								)
							)
				continue
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
	var pine := FoliageMesh.spruce()
	var boulder := SphereMesh.new()
	boulder.radius = 0.5
	boulder.height = 1
	boulder.radial_segments = 7
	boulder.rings = 2
	batch(parent, boulder, shore, Color("#74796d"))
	batch(parent, FoliageMesh.rushes(), rush, Color("#879262"))
	batch(parent, rock, stone, Color("#756957"))
	batch(parent, trunk, trunks, Color("#635641"))
	batch(parent, pine, leaves, Color("#42574c"))


static func batch(
	parent: Node3D,
	mesh: Mesh,
	placements: Array[Transform3D],
	color: Color,
	finish: StandardMaterial3D = null
) -> MultiMesh:
	if placements.is_empty():
		return null
	var paint := finish.duplicate() as StandardMaterial3D if finish else StandardMaterial3D.new()
	paint.albedo_color = color
	paint.roughness = 1
	var batch := MultiMeshInstance3D.new()
	batch.material_override = paint
	batch.multimesh = MultiMesh.new()
	batch.multimesh.transform_format = MultiMesh.TRANSFORM_3D
	batch.multimesh.mesh = mesh
	batch.multimesh.instance_count = placements.size()
	for i in placements.size():
		batch.multimesh.set_instance_transform(i, placements[i])
	parent.add_child(batch)

	return batch.multimesh
