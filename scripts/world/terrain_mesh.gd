class_name TerrainMesh
extends Node3D
## Builds one colored mesh per map chunk from the same terrain IDs used by Grid.

const CHUNK_SIZE := 16


func build(grid: Grid, terrain: TerrainSet, tile: float, seed_value: int) -> void:
	var material := ShaderMaterial.new()
	material.shader = load("res://assets/materials/ground.gdshader")
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	for y in range(0, grid.size.y, CHUNK_SIZE):
		for x in range(0, grid.size.x, CHUNK_SIZE):
			var surface := SurfaceTool.new()
			surface.begin(Mesh.PRIMITIVE_TRIANGLES)
			surface.set_material(material)
			for cy in range(y, mini(y + CHUNK_SIZE, grid.size.y)):
				for cx in range(x, mini(x + CHUNK_SIZE, grid.size.x)):
					var cell := Vector2i(cx, cy)
					var def := terrain.types[grid.terrain_types[grid.index(cell)]]
					var color := def.color.darkened(rng.randf_range(0.0, terrain.shade_variation))
					var p := Vector3(cx * tile, def.height, cy * tile)
					var east := Vector3.RIGHT * tile
					var south := Vector3.BACK * tile
					_quad(surface, p, p + east, p + east + south, p + south, Vector3.UP, color)
					for offset in [Vector2i.RIGHT, Vector2i.DOWN]:
						var neighbor: Vector2i = cell + offset
						if not grid.in_bounds(neighbor):
							continue
						var other := terrain.types[grid.terrain_types[grid.index(neighbor)]]
						if is_equal_approx(def.height, other.height):
							continue
						var a := p + east if offset == Vector2i.RIGHT else p + east + south
						var b := p + east + south if offset == Vector2i.RIGHT else p + south
						var normal := Vector3.RIGHT if offset == Vector2i.RIGHT else Vector3.BACK
						var delta_y := Vector3.UP * (other.height - def.height)
						if delta_y.y > 0.0:
							_quad(surface, b + delta_y, b, a, a + delta_y, -normal, other.color)
						else:
							_quad(surface, a, a + delta_y, b + delta_y, b, normal, color)
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
