class_name SaveLayout
extends RefCounted
## Stable identities and trusted resource definitions for archived settlements.

const MAPS := {
	"ford": preload("res://data/maps/starter_map.tres"),
	"mill": preload("res://data/maps/mill_crossing.tres")
}
const BUILDINGS := [
	"command_post",
	"house",
	"farm",
	"garden",
	"well",
	"lumber_yard",
	"scrap_workshop",
	"storage",
	"watchtower",
	"rifle_tower",
	"clinic",
	"cold_room",
	"generator",
	"floodlight",
	"radio_tower"
]
const PLOT := (
	"id road_id attachment front center door polygon house " + "path_to_street cells house_cells"
)
const BUILD := "health level target_level work_done _paid _upgrading"
const TOWER := "shots _cooldown"
const BARRIER := "along_z health progress complete opened auto_close close_pending repair_fraction"
const PERSON := (
	"resident_id display_name health cell home job shelter ward state shift_seconds worked_day "
	+ "at_station missed_rations hungry thirsty ember ember_hours diagnosed on_trip off_map "
	+ "sleep_seconds tired threat_near retreating _sim_position _path _next position visible"
)
const CLOCK := "day time_of_day speed ended _accumulator _dusk_sent _night_sent"
const SYSTEMS := {
	"jobs":
	(
		"residents sites pending last_output last_overflow last_consumed last_shortage last_dawn "
		+ "_next_id _staff _closed _dirty _off_duty"
	),
	"construction": "builder target segment repair_job projects _retry _blocked _dirty _after_dusk",
	"safety": "people last_loss threatened",
	"perimeter": "damaged towers orders _closing",
	"grower": "zones paused status _last_reset_day _turn _hours _grown _upgraded",
	"campaign": "researched won endless",
	"horde": "queued noise pressure warning_day approach _population _recent_loss",
	"expeditions":
	(
		"phase site team remaining loot report route_blocked _gate _edge _hours "
		+ "_kit _found _followers _dirty"
	),
	"admissions": "waiting report",
	"services": "sites supply demand _fuel _disabled _pulse",
	"camera": "position rotation distance pitch_deg",
	"roads": "_next_id",
	"plots": "_next_id"
}
const CROWD := (
	"_count _defs _pos _health _type _state _cooldown "
	+ "_noise_left _noise_target _dying _voice _frame"
)


static func assets(c: SaveValues) -> void:
	for name: String in BUILDINGS:
		c.register("def/" + name, load("res://data/buildings/%s.tres" % name))
	for def: BarrierDef in [
		Perimeter.BARRICADE, Perimeter.GATE, Perimeter.WALL, Perimeter.CHECKPOINT
	]:
		c.register("barrier/" + def.resource_path.get_file().get_basename(), def)
	for site in Expeditions.SITES:
		c.register("site/" + site.resource_path.get_file().get_basename(), site)
	for name: String in ["walker", "runner", "brute", "screamer", "crawler"]:
		c.register("drawn/" + name, load("res://data/zombies/%s.tres" % name))


static func cell_id(prefix: String, cell: Vector2i) -> String:
	return "%s/%d/%d" % [prefix, cell.x, cell.y]


static func register_town(w: World, c: SaveValues) -> void:
	assets(c)
	for plot: FrontagePlot in w.plots.plots.values():
		c.register("plot/%d" % plot.id, plot)
	for b: Building in w.buildings.get_children():
		if not b.is_queued_for_deletion():
			c.register(cell_id("building", b.cell), b)
	for gate: BarrierSegment in w.grid.barriers.values():
		c.register(cell_id("segment", gate.cell), gate)
		if is_instance_valid(gate.post):
			c.register(cell_id("post", gate.cell), gate.post)
	for person in w.safety.people:
		c.register("resident/%d" % person.resident_id, person)


static func capture(w: World, guide: Dictionary) -> Dictionary:
	var c := SaveValues.new()
	register_town(w, c)
	var data := {
		"map": MAPS.find_key(w.map_def),
		"roads": [],
		"plots": [],
		"buildings": [],
		"barriers": [],
		"people": [],
		"systems": {},
		"rng": {},
		"clock": c.gather(GameClock, CLOCK),
		"stocks": c.encode(Economy.stock),
		"crowd": c.gather(w.zombies, CROWD),
		"guide": guide
	}
	for road: Street in w.roads.roads.values():
		data.roads.append({"id": road.id, "points": c.encode(road.controls)})
	for plot: FrontagePlot in w.plots.plots.values():
		data.plots.append(c.gather(plot, PLOT))
	for b: Building in w.buildings.get_children():
		if b.is_queued_for_deletion():
			continue
		var item := {
			"kind": c.ids[b.def],
			"cell": c.encode(b.cell),
			"plot": c.encode(b.plot),
			"state": c.gather(b, BUILD)
		}
		if b is DefenseTower:
			item.tower = c.gather(b, TOWER)
		data.buildings.append(item)
	for gate: BarrierSegment in w.grid.barriers.values():
		var item := {
			"kind": c.ids[gate.def], "cell": c.encode(gate.cell), "state": c.gather(gate, BARRIER)
		}
		if is_instance_valid(gate.post):
			item.post = c.gather(gate.post, TOWER)
		data.barriers.append(item)
	for person in w.safety.people:
		data.people.append(c.gather(person, PERSON))
	for key: String in SYSTEMS:
		data.systems[key] = c.gather(w.get(key), SYSTEMS[key])
	for key: String in ["horde", "services", "admissions", "expeditions"]:
		var rng: RandomNumberGenerator = w.get(key).rng
		data.rng[key] = [str(rng.seed), str(rng.state)]
	return data if c.error.is_empty() and data.map != null else {}
