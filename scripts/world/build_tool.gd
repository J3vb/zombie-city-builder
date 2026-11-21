class_name BuildTool
extends Node2D
## Places buildings: ghost preview, checks, spending.

const VALID := Color(0.3, 0.9, 0.4, 0.45)
const INVALID := Color(0.95, 0.2, 0.2, 0.45)
const MARK := Color(0.1, 0.0, 0.0, 0.9)

var selected: BuildingDef
var world: World

var _hover_cell := Vector2i(-1, -1)
var _query := PackedInt32Array()


func select(def: BuildingDef) -> void:
	selected = def
	queue_redraw()


func clear() -> void:
	selected = null
	queue_redraw()


func can_place(def: BuildingDef, cell: Vector2i) -> bool:
	var cells := Grid.cells_of(cell, def.size)
	if not world.grid.is_free(cells):
		return false
	if _zombie_in(cells):
		return false
	return Economy.can_afford(def.cost)


func place(cell: Vector2i) -> bool:
	if selected == null or not can_place(selected, cell):
		return false
	Economy.spend(selected.cost)
	world.spawn_building(selected, cell)
	queue_redraw()
	return true


func _zombie_in(cells: Array[Vector2i]) -> bool:
	var tile := world.tile_size()
	for c in cells:
		var centre := world.grid.cell_to_world(c)
		if world.zombies.query(centre, tile.x * 0.71, _query) > 0:
			return true
	return false


func _process(_delta: float) -> void:
	if selected == null:
		return
	var cell := world.grid.world_to_cell(get_global_mouse_position())
	if cell != _hover_cell:
		_hover_cell = cell
		queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if selected == null:
		return
	if event.is_action_pressed("place"):
		place(world.grid.world_to_cell(get_global_mouse_position()))
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("cancel"):
		clear()
		get_viewport().set_input_as_handled()


func _draw() -> void:
	if selected == null or not world.grid.in_bounds(_hover_cell):
		return
	var tile := world.tile_size()
	var origin := world.grid.cell_to_world(_hover_cell) - tile / 2.0
	var rect := Rect2(origin, Vector2(selected.size) * tile)
	var ok := can_place(selected, _hover_cell)
	draw_rect(rect, VALID if ok else INVALID)
	if not ok:
		draw_line(rect.position, rect.end, MARK, 4.0)
		draw_line(
			Vector2(rect.end.x, rect.position.y), Vector2(rect.position.x, rect.end.y), MARK, 4.0
		)
