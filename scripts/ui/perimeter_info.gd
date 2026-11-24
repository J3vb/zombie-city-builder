extends PanelContainer
## Inspect a single perimeter cell and operate a completed gate.

var _segment: BarrierSegment
var _world: World


func _ready() -> void:
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


func _toggle_gate() -> void:
	_world.perimeter.set_gate(_segment, _segment.close_pending or not _segment.opened)


func _auto_close(value: bool) -> void:
	_segment.auto_close = value
