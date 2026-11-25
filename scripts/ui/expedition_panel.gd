class_name ExpeditionPanel
extends PanelContainer
## Regional map, team manifest and radio decisions for the active expedition.

var system: Expeditions
var selected: ExpeditionSite
var _crew: Dictionary[int, CheckBox] = {}
var _pins: Dictionary[ExpeditionSite, Button] = {}
var _last_phase := -1


func _ready() -> void:
	%Close.pressed.connect(hide)
	%Recall.pressed.connect(_recall)
	%Send.pressed.connect(_send)
	%Investigate.pressed.connect(_choice.bind(true))
	%Leave.pressed.connect(_choice.bind(false))
	for destination in Expeditions.SITES:
		var pin := Button.new()
		pin.text = destination.title
		pin.toggle_mode = true
		pin.add_theme_color_override("font_disabled_color", Color("#e1ded4"))
		pin.pressed.connect(_select.bind(destination))
		%Map.add_child(pin)
		pin.anchor_left = destination.map_position.x
		pin.anchor_top = destination.map_position.y
		pin.offset_left = -80
		pin.offset_top = -15
		_pins[destination] = pin


func open(expeditions: Expeditions) -> void:
	system = expeditions
	_last_phase = -1
	%Feedback.text = ""
	%Kit.button_pressed = false
	_select(system.site if system.site != null else Expeditions.SITES[0])
	show()
	refresh()


func _select(destination: ExpeditionSite) -> void:
	selected = destination
	for site in _pins:
		_pins[site].set_pressed_no_signal(site == selected)
	%Location.text = "%s · %s" % [selected.district, selected.title]
	%Route.text = (
		"%.0f h each way · %d h search · %d%% injury risk per search hour"
		% [selected.hours, selected.search_hours, roundi(selected.risk * 100)]
	)
	%Supplies.text = "Possible supplies · " + BuildingDef.format_cost(selected.supplies)


func refresh() -> void:
	if not visible or system == null:
		return
	var idle := system.phase == Expeditions.Phase.IDLE
	if _last_phase != system.phase:
		_last_phase = system.phase
		%Manifest.visible = idle
		%Recall.visible = system.phase in [Expeditions.Phase.GATE, Expeditions.Phase.LEAVING]
		%Choice.visible = system.phase == Expeditions.Phase.CHOICE
		for pin in _pins.values():
			pin.disabled = not idle
		if %Choice.visible:
			var encounter := system.site.encounter
			%Story.text = encounter.story
			%Investigate.text = encounter.investigate
			%Leave.text = encounter.leave
	%Progress.text = system.status()
	if idle:
		_sync_manifest()


func _sync_manifest() -> void:
	var active := PackedInt32Array()
	for person in system.world.jobs.residents:
		if (
			person == system.world.construction.builder
			or person.health <= 0
			or person.unavailable()
		):
			continue
		active.append(person.resident_id)
		var check: CheckBox = _crew.get(person.resident_id)
		if check == null:
			check = CheckBox.new()
			_crew[person.resident_id] = check
			%People.add_child(check)
		check.text = "%s · %d HP" % [person.display_name, person.health]
	for id: int in _crew.keys():
		if not active.has(id):
			_crew[id].queue_free()
			_crew.erase(id)


func _recall() -> void:
	system.recall()
	refresh()


func _send() -> void:
	var ids: Array[int] = []
	for id in _crew:
		if _crew[id].button_pressed:
			ids.append(id)
	%Feedback.text = system.launch(selected, ids, %Kit.button_pressed)
	refresh()


func _choice(investigate: bool) -> void:
	system.choose(investigate)
	refresh()
