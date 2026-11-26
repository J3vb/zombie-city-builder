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
	var pines: Array[Transform3D] = []
	var birches: Array[Transform3D] = []
	for i in 165:
		var x := rng.randf_range(-71, 71)
		var z := rng.randf_range(-69, 38)
		if (x > -11 and z > -12 and x < 34) or (x > -2 and x < 11):
			continue
		var pos := Vector3(x, 0, z)
		var s := rng.randf_range(0.8, 1.5)
		var basis := Basis(Vector3.UP, rng.randf_range(0, TAU)).scaled_local(Vector3.ONE * s)
		var trees := pines if rng.randf() < 0.72 else birches
		trees.append(Transform3D(basis, pos))
	TerrainDressing.mesh_batch(self, FoliageMesh.spruce(), pines)
	TerrainDressing.mesh_batch(self, FoliageMesh.broadleaf(), birches)
