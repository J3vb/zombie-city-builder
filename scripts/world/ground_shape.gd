class_name GroundShape
extends RefCounted
## Geometry shared by road surfaces, construction reservations and tool previews.


static func cells_of(poly: PackedVector2Array, tile: int) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	if poly.size() < 3:
		return cells
	var bounds := Rect2(poly[0], Vector2.ZERO)
	for p in poly:
		bounds = bounds.expand(p)
	var first := Vector2i((bounds.position / tile).floor())
	var end := Vector2i((bounds.end / tile).ceil())
	for y in range(first.y, end.y):
		for x in range(first.x, end.x):
			var p := Vector2(x, y) * tile
			var square := PackedVector2Array(
				[p, p + Vector2.RIGHT * tile, p + Vector2.ONE * tile, p + Vector2.DOWN * tile]
			)
			if not Geometry2D.intersect_polygons(poly, square).is_empty():
				cells.append(Vector2i(x, y))
	return cells


static func surface(polygons: Array[PackedVector2Array], scale_factor: float) -> ArrayMesh:
	var vertices := PackedVector3Array()
	for poly in polygons:
		var indices := Geometry2D.triangulate_polygon(poly)
		for index in indices:
			var p := poly[index] * scale_factor
			vertices.append(Vector3(p.x, 0, p.y))
	var mesh := ArrayMesh.new()
	if not vertices.is_empty():
		var arrays := []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = vertices
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


static func material(color: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	if color.a < 1.0:
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = color
	return mat
