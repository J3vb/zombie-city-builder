class_name Campaign
extends RefCounted
## Blueprint research and the settlement's radio call to Haven Point.

const TECHS: Array[TechDef] = [
	preload("res://data/tech/fortify.tres"),
	preload("res://data/tech/rebuild.tres"),
	preload("res://data/tech/reclaim.tres")
]
var researched: Array[StringName] = []
var won := false
var endless := false


func has_tech(id: StringName) -> bool:
	return researched.has(id)


func blocker(tech: TechDef) -> String:
	if not TECHS.has(tech):
		return "Unknown design"
	if has_tech(tech.id):
		return "Researched"
	if tech.requires != &"" and not has_tech(tech.requires):
		return "Requires " + String(tech.requires).capitalize()
	if not Economy.can_afford(tech.cost):
		return "Find blueprints and stock scrap"
	return ""


func research(tech: TechDef) -> bool:
	if not blocker(tech).is_empty():
		return false
	researched.append(tech.id)
	if Economy.spend(tech.cost):
		return true
	researched.erase(tech.id)
	return false


func permits(def: BuildingDef) -> bool:
	return def.id != &"radio_tower" or has_tech(&"reclaim")


func radio(world: World) -> Building:
	for building: Building in world.buildings.get_children():
		if (
			building.def.id == &"radio_tower"
			and building.target_level == 0
			and not building.is_queued_for_deletion()
		):
			return building
	return null


func transmit(world: World) -> bool:
	if won or endless or GameClock.ended or not has_tech(&"reclaim") or radio(world) == null:
		return false
	won = true
	GameClock.set_speed(0)
	return true


func play_endless() -> void:
	endless = true
	if not GameClock.ended:
		GameClock.set_speed(1)
