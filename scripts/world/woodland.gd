class_name Woodland
extends Node3D
## Plants seeded groves in chunks and clears individual plants when their tile is claimed.

var _grid: Grid
var _plants: Dictionary[Vector2i, Array] = {}


static func grove_noise(seed_value: int) -> FastNoiseLite:
	var noise := FastNoiseLite.new()
	noise.seed = seed_value + 208
	noise.frequency = 0.040
	return noise


static func density(noise: FastNoiseLite, x: int, y: int) -> float:
	return smoothstep(-0.06, 0.51, noise.get_noise_2d(x, y))


func plant(grid: Grid, map: MapDef, tile: float) -> void:
	_grid = grid
	var groves := grove_noise(map.map_seed)
	var species := FastNoiseLite.new()
	species.seed = map.map_seed + 311
	species.frequency = 0.062
	var rng := RandomNumberGenerator.new()
	rng.seed = map.map_seed + 193
	var scrub := FoliageMesh.rushes()
	var blades := StandardMaterial3D.new()
	blades.albedo_color = Color("#899050")
	scrub.surface_set_material(0, blades)
	var meshes: Array[Mesh] = [FoliageMesh.spruce(), FoliageMesh.broadleaf(), scrub]
	for cy in range(0, grid.size.y, 32):
		for cx in range(0, grid.size.x, 32):
			var parts: Array[Array] = [[], [], []]
			var cells: Array[Array] = [[], [], []]
			for y in range(cy, mini(cy + 32, grid.size.y)):
				for x in range(cx, mini(cx + 32, grid.size.x)):
					var cell := Vector2i(x, y)
					var ground := grid.terrain_types[grid.index(cell)]
					var border := ground == TerrainSet.Kind.BORDER
					if not border and ground != TerrainSet.Kind.GROUND:
						continue
					if cell.distance_squared_to(map.command_post_cell) < 35:
						continue
					var cover := density(groves, x, y)
					if rng.randf() > (0.58 if border else 0.012 + 0.33 * cover * cover):
						continue
					var pine_chance := 0.50 + species.get_noise_2d(x, y) * 0.80
					var kind := 0 if rng.randf() < pine_chance else 1
					var height := rng.randf_range(0.60, 1.25)
					var width := height * rng.randf_range(0.82, 1.19)
					if not border and rng.randf() < 0.32 * (1.0 - cover):
						kind = 2
						width *= 1.65
					var scale := Vector3(width, height, width)
					var basis := Basis(Vector3.UP, rng.randf_range(0, TAU)).scaled_local(scale)
					var pos := Vector3(
						x + rng.randf_range(0.14, 0.86), 0, y + rng.randf_range(0.14, 0.86)
					)
					parts[kind].append(Transform3D(basis, pos * tile))
					cells[kind].append(cell)
			for kind in meshes.size():
				if parts[kind].is_empty():
					continue
				var forms: Array[Transform3D] = []
				forms.assign(parts[kind])
				var batch := TerrainDressing.mesh_batch(self, meshes[kind], forms).multimesh
				for i in forms.size():
					var cell: Vector2i = cells[kind][i]
					_plants[cell] = [batch, i, forms[i]]
	grid.cell_edited.connect(_clear_claim)


func _clear_claim(cell: Vector2i) -> void:
	if not _plants.has(cell):
		return
	var used := (
		_grid.occupant.has(cell)
		or _grid.barriers.has(cell)
		or _grid.road_cells.has(cell)
		or _grid.parcel_cells.has(cell)
	)
	var entry := _plants[cell]
	var batch: MultiMesh = entry[0]
	var transform: Transform3D = entry[2]
	if used:
		transform.basis = Basis.from_scale(Vector3.ZERO)
	batch.set_instance_transform(entry[1], transform)
