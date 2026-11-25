class_name TownSafety
extends RefCounted
## Tracks living civilians and releases their bed and assignment after a fatal hit.

var people: Array[Resident] = []
var last_loss := ""
var threatened := 0


func lose(person: Resident, world: World) -> void:
	if not people.has(person):
		return
	people.erase(person)
	last_loss = person.display_name
	world.jobs.remove_worker(person)
	if person == world.construction.builder:
		var successor: Resident
		for survivor in people:
			if survivor.unavailable():
				continue
			successor = survivor
			if survivor.job == null:
				break
		world.construction.replace_builder(successor)
	person.home = null
	person.hide()
	person.queue_free()
	if people.is_empty():
		EventBus.game_over.emit(GameClock.day)


func shelter_removed(site: Building) -> void:
	for person in people:
		if person.shelter == site:
			person.shelter = null
			person.state = Resident.State.BLOCKED
			person.show()
