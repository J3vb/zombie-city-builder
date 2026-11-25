class_name FoliageMesh
extends RefCounted
## Reusable unit-size crowns and rushes. Every branch is part of a single instanced mesh.


static func spruce() -> ArrayMesh:
	var mesh := SurfaceTool.new()
	mesh.begin(Mesh.PRIMITIVE_TRIANGLES)
	mesh.set_smooth_group(-1)
	for tier in 4:
		var y := -0.33 + tier * 0.21
		var radius := 0.52 - tier * 0.104
		for limb in 9:
			var angle := limb * TAU / 9.0 + tier * 0.81
			var tip := Vector3(cos(angle), 0, sin(angle))
			var cross := Vector3(-tip.z, 0, tip.x)
			var root := Vector3.UP * (y + 0.22)
			var outer := tip * radius * (1.0 - 0.12 * (limb % 3)) + Vector3.UP * (y - 0.12)
			var shoulder := tip * radius * 0.44 + Vector3.UP * y
			var spread := cross * radius * 0.42
			for point in [
				root,
				shoulder + spread,
				outer,
				root,
				outer,
				shoulder - spread,
				shoulder + spread,
				shoulder - spread,
				outer
			]:
				mesh.add_vertex(point)
	mesh.generate_normals()
	return mesh.commit()


static func broadleaf() -> ArrayMesh:
	var leaf := SphereMesh.new()
	leaf.radius = 0.5
	leaf.height = 1
	leaf.radial_segments = 7
	leaf.rings = 3
	var mesh := SurfaceTool.new()
	mesh.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in 5:
		var angle := TAU * i / 5.0
		var offset := Vector3(cos(angle) * 0.22, 0.12 * sin(angle * 3), sin(angle) * 0.22)
		mesh.append_from(leaf, 0, Transform3D(Basis.from_scale(Vector3(0.65, 0.75, 0.60)), offset))
	return mesh.commit()


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
