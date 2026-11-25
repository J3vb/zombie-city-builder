extends Node3D
## The title uses the same station and meadow as the settlement, with a road and a wooded verge.


func _ready() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 409
	var road := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(12, 67)
	road.mesh = plane
	road.material_override = load("res://assets/materials/basin_asphalt.tres")
	road.position = Vector3(4, 0, 35)
	add_child(road)
	var trunks: Array[Transform3D] = []
	var low: Array[Transform3D] = []
	var high: Array[Transform3D] = []
	for i in 165:
		var x := rng.randf_range(-71, 71)
		var z := rng.randf_range(-69, 38)
		if (x > -11 and z > -12 and x < 34) or (x > -2 and x < 11):
			continue
		var pos := Vector3(x, 0, z)
		var s := rng.randf_range(0.8, 1.5)
		trunks.append(
			Transform3D(Basis.from_scale(Vector3(0.64, 3.5, 0.64) * s), pos + Vector3.UP * 1.75 * s)
		)
		low.append(
			Transform3D(Basis.from_scale(Vector3(4.8, 6.1, 4.5) * s), pos + Vector3.UP * 3.9 * s)
		)
		high.append(
			Transform3D(Basis.from_scale(Vector3(3.1, 4.9, 3.1) * s), pos + Vector3.UP * 6.2 * s)
		)
	var pine := FoliageMesh.spruce()
	TerrainDressing.batch(self, BoxMesh.new(), trunks, Color("#594d3d"))
	TerrainDressing.batch(self, pine, low, Color("#334c42"))
	TerrainDressing.batch(self, pine, high, Color("#53694c"))
