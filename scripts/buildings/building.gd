class_name Building
extends Node
## Simulation state for one placed building. Grid owns its footprint.

signal health_changed
signal upgraded

var def: BuildingDef
var cell: Vector2i
var health: int
var cells: Array[Vector2i] = []

var plot: FrontagePlot
var level := 1
var _upgrading := false

var _grid: Grid
var _balance: BalanceDef = preload("res://data/balance.tres")


func setup(
	building_def: BuildingDef, anchor: Vector2i, grid: Grid, site: FrontagePlot = null
) -> void:
	def = building_def
	cell = anchor
	plot = site
	health = max_health()
	cells = site.house_cells if site != null else Grid.cells_of(anchor, def.size)
	_grid = grid


func sim_bounds() -> Rect2:
	if plot != null:
		var rect := Rect2(plot.house[0], Vector2.ZERO)
		for p in plot.house:
			rect = rect.expand(p)
		return rect
	return Rect2(Vector2(cell * _grid.tile_size), Vector2(def.size * _grid.tile_size))


func sim_center() -> Vector2:
	return plot.center if plot != null else sim_bounds().get_center()


func max_health() -> int:
	return def.levels[level - 1].max_health if not def.levels.is_empty() else def.max_health


func upgrade() -> bool:
	if is_queued_for_deletion() or _upgrading or level >= def.levels.size() or GameClock.is_night():
		return false
	var next := def.levels[level]
	if GameClock.day < next.min_day:
		return false
	_upgrading = true
	var paid := Economy.spend(next.cost)
	if paid and is_queued_for_deletion():
		for id: StringName in next.cost:
			Economy.add(id, next.cost[id])
		paid = false
	if paid:
		health = maxi(1, roundi(float(health) / max_health() * next.max_health))
		level += 1
		upgraded.emit()
		health_changed.emit()
	_upgrading = false
	return paid


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
