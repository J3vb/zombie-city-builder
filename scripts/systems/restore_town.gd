class_name RestoreTown
extends RestoreGround
## Rebuilds a candidate world from settlement data before the active town is replaced.

# gdlint: disable=max-returns

var clock_values := {}
var stocks: Dictionary[StringName, int] = {}


func restore(w: World, data: Dictionary) -> bool:
	SaveLayout.assets(codec)
	for key: String in ["roads", "plots", "buildings", "barriers", "people"]:
		if not data.get(key) is Array or data[key].size() > w.grid.size.x * w.grid.size.y:
			return false
	if not _roads(w, data.roads) or not _plots(w, data.plots):
		return false
	if not _buildings(w, data.buildings) or not _segments(w, data.barriers):
		return false
	if not _people(w, data.people) or not _systems(w, data):
		return false
	if not _global_state(data):
		return false
	w._build_now()
	w.roads.changed.emit()
	w.plots.changed.emit()
	w.grower.zones_changed.emit()
	w.perimeter._redraw()
	w.camera._apply()
	w.zombies._hash.rebuild(w.zombies._pos, w.zombies.count())
	w.zombies.crowd_updated.emit(
		w.zombies._pos, w.zombies._type, w.zombies._state, w.zombies._defs, w.zombies.count()
	)
	for lamp: Building in w.services._lights:
		w.services._lights[lamp].visible = (
			w.services.demand > 0
			and w.services.supply >= w.services.demand
			and not w.services._disabled.has(lamp)
		)
	w.restoring = false
	return codec.error.is_empty()


func _people(w: World, records: Array) -> bool:
	if records.is_empty() or records.size() > w.plots.rules.resident_limit:
		return false
	for raw: Variant in records:
		if not raw is Dictionary:
			return false
		var id: Variant = codec.decode(raw.get("resident_id"))
		if not id is int or id < 0 or id > 2147483647:
			return false
		var p := JobBoard.RESIDENT.instantiate() as Resident
		p.setup(w, w.command_post, id, "")
		w.jobs.add_child(p)
		codec.register("resident/%d" % id, p)
	for i in records.size():
		var p := w.safety.people[i]
		if not codec.fill(p, SaveLayout.PERSON, records[i]):
			return false
		if p.health <= 0 or p._next < 0 or p._next > p._path.size() or not w.grid.in_bounds(p.cell):
			return false
		p.get_node("Alert").visible = p.retreating
	return true


func _systems(w: World, data: Dictionary) -> bool:
	if not data.get("systems") is Dictionary or not data.get("rng") is Dictionary:
		return false
	for key: String in SaveLayout.SYSTEMS:
		if not codec.fill(w.get(key), SaveLayout.SYSTEMS[key], data.systems.get(key)):
			return false
	for key: String in ["horde", "services", "admissions", "expeditions"]:
		var entry: Variant = data.rng.get(key)
		if (
			not entry is Array
			or entry.size() != 2
			or not str(entry[0]).is_valid_int()
			or not str(entry[1]).is_valid_int()
		):
			return false
		var rng: RandomNumberGenerator = w.get(key).rng
		rng.seed = int(entry[0])
		rng.state = int(entry[1])
	if not codec.fill(w.zombies, SaveLayout.CROWD, data.get("crowd")):
		return false
	var cap := w.plots.rules.max_zombies
	if (
		w.zombies.count() < 0
		or w.zombies.count() > cap
		or w.horde.approach < -1
		or w.horde.approach > 3
	):
		return false
	for field: String in [
		"_pos", "_health", "_type", "_state", "_cooldown", "_noise_left", "_noise_target", "_voice"
	]:
		if w.zombies.get(field).size() != cap:
			return false
	for i in w.zombies.count():
		if w.zombies._type[i] >= w.zombies._defs.size() or not w.zombies._pos[i].is_finite():
			return false
	for index in w.zombies._dying:
		if index < 0 or index >= w.zombies.count():
			return false
	return w.expeditions.phase == Expeditions.Phase.IDLE or w.expeditions.site != null


func _global_state(data: Dictionary) -> bool:
	if not data.get("clock") is Dictionary:
		return false
	for field in SaveLayout.CLOCK.split(" "):
		var val: Variant = codec.decode(data.clock.get(field))
		if typeof(val) != typeof(GameClock.get(field)):
			return false
		clock_values[field] = val
	var stock: Variant = codec.decode(data.get("stocks"))
	if not stock is Dictionary:
		return false
	for key: Variant in stock:
		if not key is StringName or not stock[key] is int or stock[key] < 0:
			return false
	stocks.assign(stock)
	return (
		clock_values.day >= 1
		and clock_values.time_of_day >= 0.0
		and clock_values.time_of_day < 1.0
		and clock_values.speed in [0, 1, 2, 3]
		and not clock_values.ended
	)
