class_name TerrainMesh
extends Node3D
## Shares corner heights between tiles and shades shorelines from the playable water cells.

const CHUNK_SIZE := 32
const SHORE_KERNEL := [1, 4, 6, 4, 1]


func build(grid: Grid, terrain: TerrainSet, tile: float, seed_value: int) -> void:
	var template := load("res://assets/materials/basin_ground.tres") as ShaderMaterial
	var material := template.duplicate() as ShaderMaterial
	material.set_shader_parameter("map_extent", Vector2(grid.size) * tile)
	material.set_shader_parameter("terrain_mask", _terrain_mask(grid, seed_value))
	material.set_shader_parameter("patch_offset", Vector2(seed_value % 173, seed_value % 271))
	var heights := _corner_heights(grid, terrain)
	for y in range(0, grid.size.y, CHUNK_SIZE):
		for x in range(0, grid.size.x, CHUNK_SIZE):
			var surface := SurfaceTool.new()
			surface.begin(Mesh.PRIMITIVE_TRIANGLES)
			surface.set_material(material)
			var end := mini(x + CHUNK_SIZE, grid.size.x)
			for cy in range(y, mini(y + CHUNK_SIZE, grid.size.y)):
				var cx := x
				while cx < end:
					var cell := cy * grid.size.x + cx
					var kind := grid.terrain_types[cell]
					var north := cy * (grid.size.x + 1) + cx
					var south := north + grid.size.x + 1
					var span := 1
					# Merge coplanar runs, keeping every change in bank slope.
					if (
						heights[north] == heights[north + 1]
						and heights[south] == heights[south + 1]
					):
						while (
							cx + span < end
							and grid.terrain_types[cell + span] == kind
							and heights[north + span + 1] == heights[north]
							and heights[south + span + 1] == heights[south]
						):
							span += 1
					var a := Vector3(cx * tile, heights[north], cy * tile)
					var b := Vector3((cx + span) * tile, heights[north + span], cy * tile)
					var c := Vector3(b.x, heights[south + span], (cy + 1) * tile)
					var d := Vector3(a.x, heights[south], c.z)
					surface.set_uv2(Vector2(kind, 0))
					surface.set_color(terrain.types[kind].color)
					surface.set_normal(Vector3.UP)
					for point: Vector3 in [a, b, c, a, c, d]:
						surface.add_vertex(point)
					cx += span
			surface.index()
			var chunk := MeshInstance3D.new()
			chunk.mesh = surface.commit()
			add_child(chunk)


func _corner_heights(grid: Grid, terrain: TerrainSet) -> PackedFloat32Array:
	var stride := grid.size.x + 1
	var heights := PackedFloat32Array()
	heights.resize(stride * (grid.size.y + 1))
	for y in grid.size.y:
		for x in grid.size.x:
			var height := terrain.types[grid.terrain_types[y * grid.size.x + x]].height
			if height == 0.0:
				continue
			for cy in range(y, y + 2):
				for cx in range(x, x + 2):
					var cols := 1 if cx == 0 or cx == grid.size.x else 2
					var rows := 1 if cy == 0 or cy == grid.size.y else 2
					heights[cy * stride + cx] += height / (cols * rows)
	return heights


func _terrain_mask(grid: Grid, seed_value: int) -> ImageTexture:
	# Filter water across chunk boundaries, including canal junctions and narrow crossings.
	var water := PackedInt32Array()
	water.resize(grid.terrain_types.size())
	for y in grid.size.y:
		for x in grid.size.x:
			if grid.terrain_types[y * grid.size.x + x] != TerrainSet.Kind.WATER:
				continue
			for cy in range(maxi(0, y - 2), mini(grid.size.y, y + 3)):
				for cx in range(maxi(0, x - 2), mini(grid.size.x, x + 3)):
					water[cy * grid.size.x + cx] += (
						SHORE_KERNEL[cy - y + 2] * SHORE_KERNEL[cx - x + 2]
					)
	var pixels := PackedByteArray()
	pixels.resize(grid.terrain_types.size() * 3)
	var groves := Woodland.grove_noise(seed_value)
	for y in grid.size.y:
		for x in grid.size.x:
			var index := y * grid.size.x + x
			var kind := grid.terrain_types[index]
			var cover := roundi(water[index] * 255.0 / 256.0)
			# Cell centers remain on the correct side even on one-tile islands or channels.
			pixels[3 * index] = (
				maxi(cover, 155) if kind == TerrainSet.Kind.WATER else mini(cover, 100)
			)
			pixels[3 * index + 1] = roundi(255.0 * Woodland.density(groves, x, y))
			pixels[3 * index + 2] = 255 if kind == TerrainSet.Kind.RUBBLE else 0
	var mask := Image.create_from_data(grid.size.x, grid.size.y, false, Image.FORMAT_RGB8, pixels)
	mask.generate_mipmaps()
	return ImageTexture.create_from_image(mask)
