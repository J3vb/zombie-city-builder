class_name Perimeter
extends Node3D
## Validates and pays for complete lines, manages gate traffic and releases breaches.

const BARRICADE := preload("res://data/defenses/barricade.tres")
const WALL := preload("res://data/defenses/wall.tres")
const GATE := preload("res://data/defenses/gate.tres")

var towers: Array[DefenseTower] = []
var world: World
var orders: Array[BarrierSegment] = []
var _closing: Array[BarrierSegment] = []
var _redraw_requested := false
var _view := PerimeterView.new()


func setup(owner_world: World) -> void:
	world = owner_world
	add_child(_view)
	_view.setup(world)
	EventBus.building_placed.connect(_built)
	EventBus.building_destroyed.connect(_lost)
	EventBus.dusk_started.connect(_dusk)
	GameClock.sim_tick.connect(_tick)


func _exit_tree() -> void:
	if world == null:
		return
	EventBus.building_placed.disconnect(_built)
	EventBus.building_destroyed.disconnect(_lost)
	EventBus.dusk_started.disconnect(_dusk)
	GameClock.sim_tick.disconnect(_tick)


func _built(building: Building) -> void:
	if building is DefenseTower and building.get_parent() == world.buildings:
		towers.append(building)


func _lost(building: Building) -> void:
	if building is DefenseTower:
		towers.erase(building)


static func line(a: Vector2i, b: Vector2i) -> Array[Vector2i]:
	var delta := b - a
	var end := Vector2i(b.x, a.y) if absi(delta.x) >= absi(delta.y) else Vector2i(a.x, b.y)
	var step := (end - a).sign()
	var cells: Array[Vector2i] = [a]
	while cells.back() != end:
		cells.append(cells.back() + step)
	return cells


static func price(def: BarrierDef, count: int) -> Dictionary[StringName, int]:
	var cost := def.cost.duplicate()
	for item in cost:
		cost[item] *= count
	return cost


func _busy(cell: Vector2i) -> bool:
	return world.jobs.blocks_placement([cell]) or world.zombies.occupies_cell(cell)


func blocker(def: BarrierDef, cells: Array[Vector2i]) -> String:
	var g := world.grid
	for cell in cells:
		if g.get_cost(cell) <= 0 or g.barriers.has(cell) or g.parcel_cells.has(cell):
			return "Blocked or reserved tile %s." % cell
		if g.road_cells.has(cell) and not def.gate:
			return "Use a gate to cross the street at %s." % cell
		if _busy(cell):
			return "Someone is crossing tile %s." % cell
	return ""


func order(def: BarrierDef, a: Vector2i, b: Vector2i) -> bool:
	if not world.grid.in_bounds(a) or not world.grid.in_bounds(b):
		return false
	var cells := line(a, b)
	var cost := price(def, cells.size())
	if not blocker(def, cells).is_empty() or not Economy.spend(cost):
		return false
	if not blocker(def, cells).is_empty():
		Economy.refund(cost)
		return false
	for cell in cells:
		var segment := BarrierSegment.new()
		segment.cell = cell
		segment.def = def
		segment.health = def.health
		segment.along_z = cells.front().y != cells.back().y
		world.grid.barriers[cell] = segment
		orders.append(segment)
	_changed()
	return true


func add_work(segment: BarrierSegment, dt: float) -> void:
	if segment.complete or world.grid.barriers.get(segment.cell) != segment:
		return
	segment.progress = minf(segment.def.build_seconds, segment.progress + dt)
	if segment.progress < segment.def.build_seconds or _busy(segment.cell):
		return
	segment.complete = true
	orders.erase(segment)
	world.grid.restore_ground(segment.cell)
	_changed()


func set_gate(segment: BarrierSegment, open: bool) -> void:
	if (
		not segment.complete
		or not segment.def.gate
		or world.grid.barriers.get(segment.cell) != segment
	):
		return
	_closing.erase(segment)
	segment.close_pending = not open and _busy(segment.cell)
	if segment.close_pending:
		_closing.append(segment)
	elif segment.opened != open:
		segment.opened = open
		world.grid.restore_ground(segment.cell)
		_changed()


func _dusk(_day: int) -> void:
	for segment: BarrierSegment in world.grid.barriers.values():
		if segment.def.gate and segment.opened and segment.auto_close:
			set_gate(segment, false)


func _tick(_dt: float) -> void:
	if _closing.is_empty():
		return
	for segment: BarrierSegment in _closing.duplicate():
		if not _busy(segment.cell):
			set_gate(segment, false)


func hit(segment: BarrierSegment, damage: int) -> void:
	segment.health = maxi(0, segment.health - damage)
	if segment.health == 0:
		remove(segment, false)


func remove(segment: BarrierSegment, refund: bool) -> void:
	if world.grid.barriers.get(segment.cell) != segment:
		return
	world.grid.barriers.erase(segment.cell)
	orders.erase(segment)
	_closing.erase(segment)
	world.grid.restore_ground(segment.cell)
	if refund:
		var share := (
			world.plots.rules.demolish_refund
			if segment.complete
			else 1.0 - segment.progress / segment.def.build_seconds
		)
		var materials := segment.def.cost.duplicate()
		for key in materials:
			materials[key] = floori(materials[key] * share)
		Economy.refund(materials)
	_changed()


func _changed() -> void:
	world.grid.changed.emit()
	if not _redraw_requested:
		_redraw_requested = true
		_redraw.call_deferred()


func _redraw() -> void:
	_redraw_requested = false
	if is_inside_tree():
		_view.redraw()
