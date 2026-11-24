extends Node
## Playable street fixture with a bend, a branch, two opposite parcels and a rejected overlap.


func _ready() -> void:
	var world: World = $Main.world
	var p := world.roads.entrance
	var road := world.roads.add_road(
		PackedVector2Array([p, p + Vector2(15, 150), p + Vector2(105, 285), p + Vector2(90, 420)])
	)
	var junction := road.line[road.line.size() - 8]
	world.roads.add_road(PackedVector2Array([junction, junction + Vector2(200, 36)]))
	var i := road.line.size() / 2
	var normal := road.line[i].direction_to(road.line[i + 1]).orthogonal()
	var rules := world.plots.rules
	var point := road.line[i]
	for direction in [-1.0, 1.0]:
		var cursor: Vector2 = point + normal * direction * 10.0
		if world.plots.reserve(cursor, rules.plot_frontage, rules.plot_depth) == null:
			push_error("Frontage demo could not reserve both sides of the bend.")
			return
	if world.plots.reserve(point + normal * 10.0, rules.plot_frontage, rules.plot_depth) != null:
		push_error("Frontage demo accepted an overlapping plot.")
	world.grower.step()
	world.grower.step()
	world.camera.position = world.to_view(point)
	world.camera.rotation.y = 0.38
	for click in 4:
		var wheel := InputEventMouseButton.new()
		wheel.button_index = MOUSE_BUTTON_WHEEL_DOWN
		wheel.pressed = true
		world.camera._unhandled_input(wheel)
