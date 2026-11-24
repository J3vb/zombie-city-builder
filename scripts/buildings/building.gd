class_name Building
extends Node
## Simulation state for one placed building. Grid owns its footprint.

signal health_changed

var def: BuildingDef
var cell: Vector2i
var health: int
var cells: Array[Vector2i] = []

var _grid: Grid
var _balance: BalanceDef = preload("res://data/balance.tres")


func setup(building_def: BuildingDef, anchor: Vector2i, grid: Grid) -> void:
	def = building_def
	cell = anchor
	health = def.max_health
	cells = Grid.cells_of(anchor, def.size)
	_grid = grid


func sim_bounds() -> Rect2:
	return Rect2(Vector2(cell * _grid.tile_size), Vector2(def.size * _grid.tile_size))


func sim_center() -> Vector2:
	return sim_bounds().get_center()


func take_damage(amount: int) -> void:
	if is_queued_for_deletion():
		return
	health -= amount
	if health <= 0:
		_remove(false)
	else:
		health_changed.emit()


func demolish() -> void:
	if not is_queued_for_deletion():
		_remove(true)


func _remove(demolished: bool) -> void:
	# Mark removal before notifying listeners that may replace this building.
	queue_free()
	_grid.release(cells, self)
	if demolished:
		for id: StringName in def.cost:
			Economy.add(id, floori(def.cost[id] * _balance.demolish_refund))
	else:
		_on_destroyed()
	EventBus.building_destroyed.emit(self)


func _on_destroyed() -> void:
	pass
