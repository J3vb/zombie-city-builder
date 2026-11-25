extends PanelContainer
## Supply, electrical switches, clinic results and quarantine for named residents.

var world: World
var people: Array[Resident] = []
var plants: Array[Building] = []


func _ready() -> void:
	%Close.pressed.connect(hide)
	%Toggle.pressed.connect(_switch)
	%Treat.pressed.connect(_treat)
	%Ward.pressed.connect(_ward)


func open(town: World) -> void:
	world = town
	people.clear()
	plants.clear()
	%Person.clear()
	%GridSelect.clear()
	%Feedback.text = ""
	show()
	refresh()


func refresh() -> void:
	if not visible or world == null:
		return
	%Power.text = world.services.power_text()
	var current: Array[Building] = []
	for site in world.services.sites:
		if site.def in [world.services.generator, world.services.floodlight]:
			current.append(site)
	if current != plants:
		plants = current
		%GridSelect.clear()
		for site in plants:
			%GridSelect.add_item("%s at %s" % [site.def.display_name, site.cell])
	%GridSelect.visible = not plants.is_empty()
	%Toggle.visible = %GridSelect.visible
	if %Toggle.visible:
		var enabled := world.services.operating(plants[%GridSelect.selected])
		%Toggle.text = "Switch off" if enabled else "Switch on"
	if people != world.safety.people:
		people.assign(world.safety.people)
		%Person.clear()
		for person in people:
			%Person.add_item(person.display_name)
	var patient := _person()
	if patient == null:
		return
	%Health.text = (
		"%s · %d HP · %s\n%s · Medicine %d"
		% [
			patient.activity(),
			patient.health,
			world.services.health_text(patient),
			"Medic on duty" if world.services.medic_on_duty() else "No medic on duty",
			Economy.get_amount(&"medicine")
		]
	)
	%Treat.disabled = not patient.diagnosed or not world.services.medic_on_duty() or patient.off_map
	%Ward.text = "Release from quarantine" if patient.ward != null else "Send to Cold Room"
	%Ward.disabled = (
		patient.on_trip or (patient.ward == null and world.services.free_ward() == null)
	)


func _person() -> Resident:
	var i := int(%Person.selected)
	return people[i] if i >= 0 and i < people.size() and is_instance_valid(people[i]) else null


func _switch() -> void:
	if %GridSelect.selected >= 0:
		world.services.toggle(plants[%GridSelect.selected])
	refresh()


func _treat() -> void:
	var person := _person()
	if person != null:
		%Feedback.text = (
			"Medicine given."
			if world.services.treat(person)
			else "Needs medicine, a diagnosed case and a medic. The current dose must wear off."
		)
	refresh()


func _ward() -> void:
	var person := _person()
	if person == null:
		return
	if person.ward != null:
		world.services.release(person)
		%Feedback.text = "Resident released."
	else:
		%Feedback.text = (
			"Bed reserved."
			if world.services.isolate(person)
			else "Needs a reachable free quarantine bed."
		)
	refresh()
