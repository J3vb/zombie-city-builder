class_name Building
extends Node
## Simulation state for one placed building. Grid owns its footprint.

signal health_changed
signal upgraded
signal construction_changed

var def: BuildingDef
var cell: Vector2i
var health: int
var cells: Array[Vector2i] = []

var plot: FrontagePlot
var level := 1
var target_level := 0
var work_done := 0.0
var _paid: Dictionary[StringName, int] = {}
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


func shift_output() -> int:
	if target_level == 1:
		return 0
	return (
		def.shift_yields[mini(level, def.shift_yields.size()) - 1]
		if not def.shift_yields.is_empty()
		else 0
	)


func max_health() -> int:
	return def.levels[level - 1].max_health if not def.levels.is_empty() else def.max_health


func next_level() -> BuildingLevelDef:
	return def.levels[level] if level < def.levels.size() else null


func upgrade_blocker() -> String:
	if target_level != 0:
		return "Under construction"
	var next := next_level()
	if next == null:
		return "Max level"
	if GameClock.is_night():
		return "Waits for daylight"
	if GameClock.day < next.min_day:
		return "Unlocks on day %d" % next.min_day
	var missing: Dictionary[StringName, int] = {}
	for id: StringName in next.cost:
		var shortage := next.cost[id] - Economy.get_amount(id)
		if shortage > 0:
			missing[id] = shortage
	return "" if missing.is_empty() else "Needs " + BuildingDef.format_cost(missing)


func upgrade() -> bool:
	if is_queued_for_deletion() or _upgrading or not upgrade_blocker().is_empty():
		return false
	var next := next_level()
	_upgrading = true
	var paid := Economy.spend(next.cost)
	if paid and is_queued_for_deletion():
		for id: StringName in next.cost:
			Economy.add(id, next.cost[id])
		paid = false
	if paid:
		begin_construction(level + 1, next.cost)
	_upgrading = false
	return paid


func begin_construction(target: int, cost: Dictionary[StringName, int]) -> void:
	target_level = target
	work_done = 0.0
	_paid = cost.duplicate()
	construction_changed.emit()


func required_work() -> float:
	return def.build_seconds * target_level


func project_name() -> String:
	if target_level > 0 and not def.levels.is_empty():
		return def.levels[target_level - 1].title
	return def.display_name


func pick_height() -> float:
	var height := def.view_height if def.levels.is_empty() else def.levels[level - 1].height
	if target_level == 1:
		return 2.0
	return maxf(2.0, height + 0.4) if target_level > 1 else height


func add_build_work(seconds: float) -> void:
	if target_level == 0 or is_queued_for_deletion() or seconds <= 0.0:
		return
	work_done = minf(work_done + seconds, required_work())
	if work_done < required_work():
		return
	var completed := target_level
	if completed > 1:
		var new_max := def.levels[completed - 1].max_health
		health = maxi(1, roundi(float(health) / max_health() * new_max))
		level = completed
	_clear_project()
	if completed == 1:
		EventBus.building_placed.emit(self)
	else:
		upgraded.emit()
		health_changed.emit()


func unused_materials() -> Dictionary[StringName, int]:
	var result: Dictionary[StringName, int] = {}
	if target_level == 0:
		return result
	var unused := 1.0 - work_done / required_work()
	for id in _paid:
		var amount := floori(_paid[id] * unused)
		if amount > 0:
			result[id] = amount
	return result


func _clear_project() -> void:
	target_level = 0
	work_done = 0.0
	_paid.clear()
	construction_changed.emit()


func cancel_construction() -> void:
	if target_level == 0 or is_queued_for_deletion():
		return
	if target_level == 1:
		demolish()
		return
	var refund := unused_materials()
	_clear_project()
	for id in refund:
		Economy.add(id, refund[id])


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
		var refund := unused_materials()
		if target_level != 1:
			for id in def.cost:
				refund[id] = refund.get(id, 0) + floori(def.cost[id] * _balance.demolish_refund)
		for id in refund:
			Economy.add(id, refund[id])
	else:
		_on_destroyed()
	EventBus.building_destroyed.emit(self)


func _on_destroyed() -> void:
	pass
