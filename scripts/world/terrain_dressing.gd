class_name TerrainDressing
extends RefCounted
## Seeded shoreline reeds, boulders and low debris in the mill ruins.


static func build(parent: Node3D, grid: Grid, tile: float, seed_value: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value + 73
	var reed_beds := FastNoiseLite.new()
	reed_beds.seed = seed_value + 137
	reed_beds.frequency = 0.16
	var rush: Array[Transform3D] = []
	var shore: Array[Transform3D] = []
	var stone: Array[Transform3D] = []
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
					if grid.get_cost(cell + direction) > 0:
						var point := (
							Vector3(
								x + 0.5 + 0.43 * direction.x, -0.21, y + 0.5 + 0.43 * direction.y
							)
							* Vector3(tile, 1, tile)
						)
						var turn := Basis(Vector3.UP, rng.randf_range(0, TAU))
						var stems := roundi(
							5.0 * smoothstep(-0.19, 0.43, reed_beds.get_noise_2d(x, y))
						)
						for i in stems:
							var offset := Vector3(
								rng.randf_range(-0.5, 0.5), 0, rng.randf_range(-0.5, 0.5)
							)
							var scale := Vector3(1.7, 1.65, 1.7) * rng.randf_range(0.7, 1.45)
							rush.append(Transform3D(turn.scaled(scale), point + offset * tile))
						if rng.randf() < 0.10:
							shore.append(
								Transform3D(
									turn.scaled(Vector3(1.6, 1.1, 1.9)), point + Vector3.RIGHT * 0.8
								)
							)
				continue
			if kind != TerrainSet.Kind.RUBBLE:
				continue
			if rng.randf() > 0.38:
				continue
			var point := (
				Vector3(x + rng.randf_range(0.25, 0.75), 0, y + rng.randf_range(0.25, 0.75)) * tile
			)
			var turn := Basis(Vector3.UP, rng.randf_range(0, TAU))
			var scale := rng.randf_range(0.65, 1.25)
			var size := Vector3(1.25, 0.35, 0.70) * scale
			stone.append(Transform3D(turn.scaled(size), point + Vector3.UP * size.y * 0.5))
	var rock := BoxMesh.new()
	var boulder := SphereMesh.new()
	boulder.radius = 0.5
	boulder.height = 1
	boulder.radial_segments = 7
	boulder.rings = 2
	batch(parent, boulder, shore, Color("#62675f"))
	batch(parent, FoliageMesh.rushes(), rush, Color("#72774d"))
	batch(parent, rock, stone, Color("#756957"))


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
	var batch := mesh_batch(parent, mesh, placements)
	batch.material_override = paint
	return batch.multimesh


static func mesh_batch(
	parent: Node3D, mesh: Mesh, placements: Array[Transform3D]
) -> MultiMeshInstance3D:
	var batch := MultiMeshInstance3D.new()
	batch.multimesh = MultiMesh.new()
	batch.multimesh.transform_format = MultiMesh.TRANSFORM_3D
	batch.multimesh.mesh = mesh
	batch.multimesh.instance_count = placements.size()
	for i in placements.size():
		batch.multimesh.set_instance_transform(i, placements[i])
	parent.add_child(batch)
	return batch
