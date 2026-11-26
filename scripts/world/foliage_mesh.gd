class_name FoliageMesh
extends RefCounted
## Meter-scale trees with tapered wood and textured sprays distributed around each crown.

const BOUGHS := "res://assets/materials/basin_boughs.tres"


static func spruce() -> ArrayMesh:
	var wood := _wood_surface()
	_stem(wood, Vector3.ZERO, Vector3(0.04, 6.85, 0), 0.19, 0.025, Color("#665745"))
	var needles := SurfaceTool.new()
	needles.begin(Mesh.PRIMITIVE_TRIANGLES)
	needles.set_material(load(BOUGHS))
	for tier in 7:
		var level := float(tier) / 6.0
		var count := 9 - floori(tier * 0.5)
		for limb in count:
			var angle := TAU * limb / count + tier * 2.40 + 0.12 * sin(limb * 7.1)
			var ray := Vector3(cos(angle), 0, sin(angle))
			var reach := lerpf(2.68, 0.39, level) * (0.90 + 0.19 * sin(limb + tier * 2.3))
			var base := Vector3.UP * (2.15 + tier * 0.84 + 0.30 * sin(limb * 2.3 + tier))
			var droop := lerpf(-1.05, 0.70, level) + 0.15 * sin(limb)
			var tip := base + ray * reach + Vector3.UP * droop
			_spray(needles, base, tip, ray, reach * 0.49, 0.5, 0.70 + level * 0.28)
	return needles.commit(wood.commit())


static func broadleaf() -> ArrayMesh:
	var wood := _wood_surface()
	var bark := Color("#b5afa0")
	var fork := Vector3(0.09, 2.4, -0.07)
	_stem(wood, Vector3.ZERO, fork, 0.19, 0.135, bark.darkened(0.23))
	var leaves := SurfaceTool.new()
	leaves.begin(Mesh.PRIMITIVE_TRIANGLES)
	leaves.set_material(load(BOUGHS))
	# Offset scaffold limbs make a many-lobed crown, with light between the outer twigs.
	for limb in 7:
		var angle := limb * 2.4
		var ray := Vector3(cos(angle), 0, sin(angle))
		var radius := 1.45 - limb * 0.155
		var elbow := fork + ray * radius + Vector3.UP * (1.40 + limb * 0.32)
		var leader := elbow + ray * 0.38 + Vector3.UP * (0.75 + limb * 0.12)
		_stem(wood, fork, elbow, 0.10, 0.06, bark)
		_stem(wood, elbow, leader, 0.06, 0.025, bark)
		for twig in 7:
			var bearing := angle + twig * 2.40
			var out := Vector3(cos(bearing), 0, sin(bearing))
			var rise := 0.29 + 0.33 * (twig % 4)
			var base := elbow.lerp(leader, twig / 7.0) - out * 0.23
			var tip := base + out * (1.39 + 0.22 * sin(limb + twig)) + Vector3.UP * rise
			_spray(leaves, base, tip, out, 0.91, 0.0, 0.72 + 0.033 * limb + rise * 0.12)
	return leaves.commit(wood.commit())


static func _wood_surface() -> SurfaceTool:
	var bark := StandardMaterial3D.new()
	bark.vertex_color_use_as_albedo = true
	bark.roughness = 1.0
	var wood := SurfaceTool.new()
	wood.begin(Mesh.PRIMITIVE_TRIANGLES)
	wood.set_material(bark)
	return wood


static func _stem(
	wood: SurfaceTool, base: Vector3, tip: Vector3, foot: float, end: float, color: Color
) -> void:
	var axis := (tip - base).normalized()
	var tangent := axis.cross(Vector3.FORWARD).normalized()
	for i in 6:
		var a := tangent.rotated(axis, TAU * i / 6.0)
		var b := tangent.rotated(axis, TAU * (i + 1) / 6.0)
		wood.set_color(color.darkened(0.07 * (i % 3)))
		wood.set_normal((a + b).normalized())
		for point: Vector3 in [
			base + a * foot,
			tip + a * end,
			base + b * foot,
			base + b * foot,
			tip + a * end,
			tip + b * end,
		]:
			wood.add_vertex(point)


static func _spray(
	mesh: SurfaceTool,
	base: Vector3,
	tip: Vector3,
	ray: Vector3,
	width: float,
	atlas_u: float,
	light: float
) -> void:
	var side := Vector3(-ray.z, 0, ray.x) * width
	var mid := base.lerp(tip, 0.53) + Vector3.UP * width * 0.32
	var verts := [base - side, base + side, tip + side, tip - side, mid]
	var uvs := [Vector2(0, 1), Vector2(1, 1), Vector2(1, 0), Vector2(0, 0), Vector2(0.5, 0.5)]
	for i: int in [0, 4, 1, 1, 4, 2, 2, 4, 3, 3, 4, 0]:
		var uv: Vector2 = uvs[i]
		mesh.set_uv(Vector2(atlas_u + uv.x * 0.498 + 0.001, uv.y))
		var normal := Vector3.UP * 0.90 + ray * (1.2 - uv.y) + side.normalized() * (uv.x - 0.5)
		mesh.set_normal(normal.normalized())
		var exposure := light * (1.0 - 0.20 * uv.y)
		mesh.set_color(Color(exposure, exposure, exposure))
		mesh.add_vertex(verts[i])


static func rushes() -> ArrayMesh:
	var mesh := SurfaceTool.new()
	mesh.begin(Mesh.PRIMITIVE_TRIANGLES)
	mesh.set_smooth_group(-1)
	for i in 11:
		var angle := i * 2.40
		var ray := Vector3(cos(angle), 0, sin(angle))
		var pos := ray * (0.09 + 0.03 * (i % 4))
		var side := Vector3(-ray.z, 0, ray.x) * 0.052
		var tip := pos + ray * 0.20 + Vector3.UP * (0.40 + (i % 3) * 0.16)
		for point in [pos - side, tip, pos + side, pos + side, tip, pos - side]:
			mesh.add_vertex(point)
	mesh.generate_normals()
	return mesh.commit()
