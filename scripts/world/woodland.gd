class_name Woodland
extends Node3D
## Clustered birch, spruce and scrub. Individual plants clear when the player claims their tile.

var _grid: Grid
var _plants: Dictionary[Vector2i, Array] = {}


func plant(grid: Grid, map: MapDef, tile: float) -> void:
	_grid = grid
	var noise := FastNoiseLite.new()
	noise.seed = map.map_seed + 208
	noise.frequency = 0.037
	var rng := RandomNumberGenerator.new()
	rng.seed = map.map_seed + 193
	var pine := FoliageMesh.spruce()
	var crown := FoliageMesh.broadleaf()
	var shrubs := FoliageMesh.rushes()
	var trunk := BoxMesh.new()
	var meshes: Array[Mesh] = [trunk, pine, pine, crown, crown, shrubs]
	var palettes := [
		Color("#665749"),
		Color("#255047"),
		Color("#436854"),
		Color("#728356"),
		Color("#596940"),
		Color("#889247")
	]
	for cy in range(0, grid.size.y, 32):
		for cx in range(0, grid.size.x, 32):
			var parts: Array[Array] = [[], [], [], [], [], []]
			var cells: Array[Array] = [[], [], [], [], [], []]
			for y in range(cy, mini(cy + 32, grid.size.y), 2):
				for x in range(cx, mini(cx + 32, grid.size.x), 2):
					var cell := Vector2i(x + rng.randi_range(0, 1), y + rng.randi_range(0, 1))
					if (
						not grid.in_bounds(cell)
						or grid.terrain_types[grid.index(cell)] != TerrainSet.Kind.GROUND
						or cell.distance_squared_to(map.command_post_cell) < 35
					):
						continue
					var grove := noise.get_noise_2d(cell.x, cell.y)
					if rng.randf() > clampf(grove * 0.95 + 0.12, 0.035, 0.68):
						continue
					var p := Vector3(cell.x + 0.5, 0, cell.y + 0.5) * tile
					var scale := rng.randf_range(0.72, 1.23)
					if grove < 0.02:
						_piece(parts, cells, 5, cell, p, Vector3(1.9, 1.05, 1.6) * scale)
					else:
						_piece(
							parts,
							cells,
							0,
							cell,
							p + Vector3.UP * 1.8 * scale,
							Vector3(0.42, 3.6, 0.42) * scale
						)
						if rng.randf() < 0.54:
							_piece(
								parts,
								cells,
								1,
								cell,
								p + Vector3.UP * 3.2 * scale,
								Vector3(3.7, 4.3, 3.4) * scale
							)
							_piece(
								parts,
								cells,
								2,
								cell,
								p + Vector3.UP * 4.7 * scale,
								Vector3(2.6, 3.8, 2.6) * scale
							)
						else:
							_piece(
								parts,
								cells,
								4,
								cell,
								p + Vector3.UP * 3.6 * scale,
								Vector3(3.5, 3.6, 3.0) * scale
							)
							_piece(
								parts,
								cells,
								3,
								cell,
								p + Vector3(0.4, 4.9, 0) * scale,
								Vector3(2.9, 3.1, 2.8) * scale
							)
			for kind in parts.size():
				if parts[kind].is_empty():
					continue
				var forms: Array[Transform3D] = []
				forms.assign(parts[kind])
				var batch := TerrainDressing.batch(self, meshes[kind], forms, palettes[kind])
				for i in forms.size():
					var cell: Vector2i = cells[kind][i]
					if not _plants.has(cell):
						_plants[cell] = []
					_plants[cell].append([batch, i, forms[i]])
	grid.cell_edited.connect(_clear_claim)


func _piece(
	parts: Array[Array],
	cells: Array[Array],
	kind: int,
	cell: Vector2i,
	position: Vector3,
	scale: Vector3
) -> void:
	parts[kind].append(Transform3D(Basis.from_scale(scale), position))
	cells[kind].append(cell)


func _clear_claim(cell: Vector2i) -> void:
	if not _plants.has(cell):
		return
	var used := (
		_grid.occupant.has(cell)
		or _grid.barriers.has(cell)
		or _grid.road_cells.has(cell)
		or _grid.parcel_cells.has(cell)
	)
	for entry: Array in _plants[cell]:
		var batch: MultiMesh = entry[0]
		var transform: Transform3D = entry[2]
		if used:
			transform.basis = Basis.from_scale(Vector3.ZERO)
		batch.set_instance_transform(entry[1], transform)
