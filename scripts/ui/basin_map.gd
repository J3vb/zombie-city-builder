extends Panel
## Draw a regional route map behind the six selectable expedition stops.

const STATION := Vector2(0.42, 0.83)
const RIVER: Array[Vector2] = [
	Vector2(-0.02, 0.04),
	Vector2(0.25, 0.19),
	Vector2(0.29, 0.50),
	Vector2(0.38, 0.6),
	Vector2(0.39, 0.78),
	Vector2(0.48, 1.02)
]
const RIDGE: Array[Vector2] = [
	Vector2(0, 0),
	Vector2(0.65, 0),
	Vector2(0.55, 0.12),
	Vector2(0.34, 0.26),
	Vector2(0.17, 0.25),
	Vector2(0, 0.38)
]


func _ready() -> void:
	clip_contents = true


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color("#454b3c"))
	var ridge := PackedVector2Array()
	for point in RIDGE:
		ridge.append(point * size)
	draw_colored_polygon(ridge, Color("#343f32"))
	for site in Expeditions.SITES:
		var stop := site.map_position * size
		var mid := Vector2(stop.x, STATION.y * size.y)
		draw_line(STATION * size, mid, Color("#8c8665"), 2.5, true)
		draw_line(mid, stop, Color("#8c8665"), 2.5, true)
	for i in range(1, RIVER.size()):
		draw_line(RIVER[i - 1] * size, RIVER[i] * size, Color("#627c7e"), 5, true)
	# Dense city blocks, the two smaller towns and the fire station share one map scale.
	for center: Vector2 in [Vector2(0.81, 0.4), Vector2(0.16, 0.60), Vector2(0.61, 0.83)]:
		var cols := 7 if center.x > 0.75 else 3
		for row in 3:
			for col in cols:
				var corner := center * size + Vector2((col - cols / 2) * 9, row * 8 - 10)
				draw_rect(Rect2(corner, Vector2(6, 5)), Color("#707366"))
	draw_circle(STATION * size, 4, Color("#ffcf75"))
	draw_string(
		ThemeDB.fallback_font,
		STATION * size + Vector2(8, 13),
		"Station 4",
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		13,
		Color("#f8dab0")
	)
