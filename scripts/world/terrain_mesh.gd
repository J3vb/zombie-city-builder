class_name TerrainMesh
extends Node3D
## Builds one colored mesh per map chunk from the same terrain IDs used by Grid.

const CHUNK_SIZE := 32


func build(grid: Grid, terrain: TerrainSet, tile: float, _seed_value: int) -> void:
	var material := load("res://assets/materials/basin_ground.tres") as ShaderMaterial
	for y in range(0, grid.size.y, CHUNK_SIZE):
		for x in range(0, grid.size.x, CHUNK_SIZE):
			var surface := SurfaceTool.new()
			surface.begin(Mesh.PRIMITIVE_TRIANGLES)
			surface.set_material(material)
			for cy in range(y, mini(y + CHUNK_SIZE, grid.size.y)):
				var cx := x
				var end := mini(x + CHUNK_SIZE, grid.size.x)
				while cx < end:
					var cell := Vector2i(cx, cy)
					var kind := grid.terrain_types[grid.index(cell)]
					var def := terrain.types[kind]
					var stop := cx + 1
					while stop < end and grid.terrain_types[cy * grid.size.x + stop] == kind:
						stop += 1
					var p := Vector3(cx * tile, def.height, cy * tile)
					var east := Vector3.RIGHT * tile * (stop - cx)
					var south := Vector3.BACK * tile
					_quad(surface, p, p + east, p + east + south, p + south, Vector3.UP, def.color)
					if def.height < 0.0:
						_banks(surface, grid, terrain, cy, cx, stop, tile, def)
					cx = stop
			surface.index()
			var chunk := MeshInstance3D.new()
			chunk.mesh = surface.commit()
			add_child(chunk)


func _quad(
	s: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, n: Vector3, color: Color
) -> void:
	s.set_color(color)
	s.set_normal(n)
	for vertex in [a, b, c, a, c, d]:
		s.add_vertex(vertex)


func _banks(
	surface: SurfaceTool,
	grid: Grid,
	terrain: TerrainSet,
	row: int,
	start: int,
	stop: int,
	tile: float,
	def: TerrainDef
) -> void:
	for x in range(start, stop):
		var cell := Vector2i(x, row)
		for dir: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			var neighbor := cell + dir
			if not grid.in_bounds(neighbor):
				continue
			var other := terrain.types[grid.terrain_types[grid.index(neighbor)]]
			if other.height <= def.height:
				continue
			var normal := Vector3(-dir.x, 0, -dir.y)
			var mid := (
				Vector3(x + 0.5 + dir.x * 0.5, def.height, row + 0.5 + dir.y * 0.5)
				* Vector3(tile, 1, tile)
			)
			var half := Vector3(dir.y, 0, -dir.x) * tile * 0.5
			var up := Vector3.UP * (other.height - def.height)
			_quad(
				surface,
				mid + half,
				mid - half,
				mid - half + up,
				mid + half + up,
				normal,
				other.color
			)
