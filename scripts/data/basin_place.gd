class_name BasinPlace
extends Resource
## A derelict settlement laid out in blocks with walkable streets between the buildings.

@export var title: String
@export var origin: Vector2i
@export var blocks := Vector2i(4, 3)
@export var city := false
@export var seed_value := 1


func extent() -> Rect2i:
	return Rect2i(origin, blocks * 7 + Vector2i.ONE)


func footprints() -> Array[Rect2i]:
	var result: Array[Rect2i] = []
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	for y in blocks.y:
		for x in blocks.x:
			if rng.randf() < 0.16:
				continue
			var span := (
				Vector2i(rng.randi_range(3, 5), rng.randi_range(3, 5))
				if city
				else Vector2i(rng.randi_range(2, 3), rng.randi_range(2, 4))
			)
			result.append(
				Rect2i(
					(
						origin
						+ Vector2i(x, y) * 7
						+ Vector2i(rng.randi_range(1, 2), rng.randi_range(1, 2))
					),
					span
				)
			)
	return result
