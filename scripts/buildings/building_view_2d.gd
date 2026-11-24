extends Node2D
## Draws the current 2D building and damage bar at its simulation footprint.

const OUTLINE := Color(0.05, 0.05, 0.05)
const BAR_BACK := Color(0.1, 0.1, 0.1)
const BAR_FRONT := Color(0.85, 0.2, 0.15)

@onready var building := get_parent() as Building


func _ready() -> void:
	if building.def != null:
		position = building.sim_bounds().position
	building.health_changed.connect(queue_redraw)


func _draw() -> void:
	if building.def == null:
		return
	var rect := Rect2(Vector2.ZERO, building.sim_bounds().size)
	draw_rect(rect.grow(-2), building.def.color)
	draw_rect(rect.grow(-2), OUTLINE, false, 3.0)
	var font := ThemeDB.fallback_font
	var font_size := int(rect.size.y / building.def.size.y * 0.9)
	var label := building.def.display_name.left(1)
	var text_size := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
	var text_pos := rect.get_center() + Vector2(-text_size.x / 2.0, font_size * 0.35)
	draw_string(font, text_pos, label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, OUTLINE)
	if building.health < building.def.max_health:
		var bar := Rect2(4, 4, rect.size.x - 8, 6)
		draw_rect(bar, BAR_BACK)
		bar.size.x *= float(building.health) / building.def.max_health
		draw_rect(bar, BAR_FRONT)
