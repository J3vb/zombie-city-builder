class_name Building
extends Node2D
## A placed building. Draws a placeholder block until real art exists.

const OUTLINE := Color(0.05, 0.05, 0.05)
const BAR_BACK := Color(0.1, 0.1, 0.1)
const BAR_FRONT := Color(0.85, 0.2, 0.15)

var def: BuildingDef
var cell: Vector2i
var health: int
var cells: Array[Vector2i] = []

var _grid: Grid
var _tile: Vector2
var _balance: BalanceDef = preload("res://data/balance.tres")


func setup(building_def: BuildingDef, anchor: Vector2i, grid: Grid, tile: Vector2) -> void:
	def = building_def
	cell = anchor
	health = def.max_health
	cells = Grid.cells_of(anchor, def.size)
	_grid = grid
	_tile = tile
	position = grid.cell_to_world(anchor) - tile / 2.0
	queue_redraw()


func take_damage(amount: int) -> void:
	if health <= 0:
		return
	health -= amount
	queue_redraw()
	if health <= 0:
		_on_destroyed()
		_remove()


func demolish() -> void:
	for id_key: StringName in def.cost:
		Economy.add(id_key, floori(def.cost[id_key] * _balance.demolish_refund))
	_remove()


func _on_destroyed() -> void:
	pass


func _remove() -> void:
	_grid.release(cells)
	EventBus.building_destroyed.emit(self)
	queue_free()


func _draw() -> void:
	var rect := Rect2(Vector2.ZERO, Vector2(def.size) * _tile)
	draw_rect(rect.grow(-2), def.color)
	draw_rect(rect.grow(-2), OUTLINE, false, 3.0)
	var font := ThemeDB.fallback_font
	var font_size := int(_tile.y * 0.9)
	var label := def.display_name.left(1)
	var text_size := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
	var text_pos := rect.get_center() + Vector2(-text_size.x / 2.0, font_size * 0.35)
	draw_string(font, text_pos, label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, OUTLINE)
	if health < def.max_health:
		var bar := Rect2(4, 4, rect.size.x - 8, 6)
		draw_rect(bar, BAR_BACK)
		bar.size.x *= float(health) / def.max_health
		draw_rect(bar, BAR_FRONT)
