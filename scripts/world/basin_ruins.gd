class_name BasinRuins
extends RefCounted
## Batches the standing walls, rooflines and windows over the impassable ruin footprints.


static func build(parent: Node3D, places: Array[BasinPlace], tile: float) -> void:
	var finish := load("res://assets/materials/station_facade.tres") as StandardMaterial3D
	for place in places:
		var masonry: Array[Transform3D] = []
		var brick: Array[Transform3D] = []
		var roofs: Array[Transform3D] = []
		var windows: Array[Transform3D] = []
		var tanks: Array[Transform3D] = []
		var joists: Array[Transform3D] = []
		var pitched: Array[Transform3D] = []
		var rng := RandomNumberGenerator.new()
		rng.seed = place.seed_value
		for rect in place.footprints():
			var center := Vector2(rect.position) + Vector2(rect.size) * 0.5
			var p := Vector3(center.x * tile, 0, center.y * tile)
			var w := rect.size.x * tile - 0.9
			var d := rect.size.y * tile - 0.9
			var floors := rng.randi_range(2, 6) if place.city else rng.randi_range(1, 2)
			var height := floors * 2.9
			var walls := brick if rng.randf() < 0.42 else masonry
			walls.append(_box(p + Vector3.UP * height * 0.5, Vector3(w, height, d)))
			if place.city:
				roofs.append(
					_box(p + Vector3.UP * (height + 0.18), Vector3(w + 0.4, 0.36, d + 0.4))
				)
				roofs.append(
					_box(
						p + Vector3(w * 0.2, height + 0.8, -d * 0.2),
						Vector3(w * 0.27, 1.4, d * 0.30)
					)
				)
				if rng.randf() < 0.22:
					var center_roof := p + Vector3(-w * 0.19, height, d * 0.10)
					joists.append(_box(center_roof + Vector3.UP * 1.0, Vector3(2.4, 2.0, 2.4)))
					tanks.append(_box(center_roof + Vector3.UP * 3.05, Vector3(3.4, 2.4, 3.4)))
				if rng.randf() < 0.44:
					for end in [-1, 1]:
						joists.append(
							_box(
								p + Vector3(end * w * 0.47, height + 0.65, 0),
								Vector3(0.38, 1.2, d * 0.94)
							)
						)
					joists.append(
						_box(p + Vector3(0, height + 0.65, d * 0.47), Vector3(w * 0.94, 1.2, 0.38))
					)
				elif floors >= 4:
					walls.append(
						_box(
							p + Vector3(-w * 0.12, height + 1.45, d * 0.12),
							Vector3(w * 0.72, 2.9, d * 0.67)
						)
					)
					roofs.append(
						_box(
							p + Vector3(-w * 0.12, height + 3.0, d * 0.12),
							Vector3(w * 0.75, 0.3, d * 0.69)
						)
					)
			else:
				pitched.append(
					_box(p + Vector3.UP * (height + 0.9), Vector3(w + 0.5, 1.8, d + 0.5))
				)
				joists.append(
					_box(p + Vector3(w * 0.25, height + 1.55, -d * 0.12), Vector3(0.88, 2.7, 1.15))
				)
			for floor_id in floors:
				var level := 1.65 + floor_id * 2.9
				for side in [-1, 1]:
					for bay in 3:
						if rng.randf() < 0.13:
							continue
						var offset := (bay - 1) * 0.27
						windows.append(
							_box(
								p + Vector3(w * offset, level, side * (d * 0.5 + 0.02)),
								Vector3(w * 0.13, 1.08, 0.10)
							)
						)
						windows.append(
							_box(
								p + Vector3(side * (w * 0.5 + 0.02), level, d * offset),
								Vector3(0.10, 1.08, d * 0.13)
							)
						)
		var tank := CylinderMesh.new()
		tank.height = 1
		tank.top_radius = 0.48
		tank.bottom_radius = 0.5
		tank.radial_segments = 9
		TerrainDressing.batch(parent, tank, tanks, Color("#666e65"))
		TerrainDressing.batch(parent, BoxMesh.new(), joists, Color("#6b5e51"))
		var box := BoxMesh.new()
		TerrainDressing.batch(parent, box, masonry, Color("#b6b6a9"), finish)
		TerrainDressing.batch(parent, BoxMesh.new(), brick, Color("#9b7260"), finish)
		TerrainDressing.batch(parent, BoxMesh.new(), roofs, Color("#626766"))
		TerrainDressing.batch(parent, BoxMesh.new(), windows, Color("#394644"))
		TerrainDressing.batch(parent, PrismMesh.new(), pitched, Color("#805746"))


static func _box(point: Vector3, size: Vector3) -> Transform3D:
	return Transform3D(Basis.from_scale(size), point)
