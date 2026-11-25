extends TestCase
## Every advertised upgrade must resolve to its own model in the exported game.


func test_every_authored_building_tier_has_a_loadable_model() -> void:
	for id: String in ["house", "farm", "storage", "scrap_workshop"]:
		var def := load("res://data/buildings/%s.tres" % id) as BuildingDef
		var seen: Array[String] = []
		for level in def.levels:
			assert_true(level.model_path not in seen, id + " repeats a tier model")
			var scene := load(level.model_path) as PackedScene
			assert_true(scene != null, id + " is missing " + level.model_path)
			if scene != null:
				var model := scene.instantiate() as Node3D
				assert_true(model != null and model.get_child_count() > 0)
				model.free()
			seen.append(level.model_path)
