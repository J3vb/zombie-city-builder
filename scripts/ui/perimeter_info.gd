extends PanelContainer
## Inspect a single perimeter cell and operate a completed gate.

var _segment: BarrierSegment
var _world: World


func _ready() -> void:
	%Guard.about_to_popup.connect(_list_guards)
	%Guard.get_popup().id_pressed.connect(_staff)
	%Switch.pressed.connect(_toggle_gate)
	%AutoClose.toggled.connect(_auto_close)


func refresh(world: World, segment: BarrierSegment) -> void:
	_world = world
	_segment = segment
	visible = segment != null and world.grid.barriers.get(segment.cell) == segment
	if not visible:
		return
	%Name.text = segment.def.title
	%Details.text = "Health   %d / %d" % [segment.health, segment.def.health]
	if not segment.complete:
		%Details.text += (
			"\nConstruction   %d%%" % floori(100 * segment.progress / segment.def.build_seconds)
		)
	if segment in world.perimeter.damaged:
		%Details.text += (
			"\n"
			+ (
				"Waiting for a safe repair"
				if not world.perimeter.safe_to_repair(segment)
				else "Builder repair pending"
			)
		)
	%Guard.visible = segment.complete and segment.def == Perimeter.WALL
	if %Guard.visible:
		var person := world.jobs.worker_at(segment.post) if segment.post != null else null
		%Guard.text = (
			"Assign sentry"
			if person == null
			else "%s · %s" % [person.display_name, person.activity()]
		)
	var gate := segment.complete and segment.def.gate
	%Switch.visible = gate
	%AutoClose.visible = gate
	if gate:
		var status := "Open" if segment.opened else "Closed"
		if segment.close_pending:
			status = "Waiting for crossing to clear"
		%Details.text += "\n" + status
		%Switch.text = (
			"Cancel closing"
			if segment.close_pending
			else ("Close gate" if segment.opened else "Open gate")
		)
		%AutoClose.set_pressed_no_signal(segment.auto_close)


func _list_guards() -> void:
	var menu := %Guard.get_popup() as PopupMenu
	menu.clear()
	if _segment.post != null:
		menu.add_item("Release wall post", 0)
	for person in _world.jobs.residents:
		if person != _world.construction.builder:
			menu.add_item(person.display_name, person.resident_id)


func _staff(id: int) -> void:
	if id == 0:
		_world.perimeter.release_post(_segment)
		return
	for person in _world.jobs.residents:
		if person.resident_id == id and not _world.perimeter.staff_wall(_segment, person):
			%Guard.text = "No route to wall"


func _toggle_gate() -> void:
	_world.perimeter.set_gate(_segment, _segment.close_pending or not _segment.opened)


func _auto_close(value: bool) -> void:
	_segment.auto_close = value
