class_name RoadTool
extends Node3D
## Click to build and continue from the endpoint, or step back with the right button.

enum Mode { STRAIGHT, CURVED, FREEFORM }

var active := false
var mode := Mode.STRAIGHT
var angle_snap := true:
	set(enabled):
		angle_snap = enabled
		_invalidate()
var points := PackedVector2Array()
var hint := ""
var world: World

var _chained := false
var _direction := Vector2.RIGHT
var _guide := RoadGuide.new()
var _surfaces: Dictionary[int, StreetSurface] = {}
var _junctions := StreetSurface.new()
var _apron := MeshInstance3D.new()
var _entrance := MeshInstance3D.new()
var _last_cursor := Vector2.INF
var _asphalt: Material


func setup(owner_world: World) -> void:
	_asphalt = load(StreetSurface.ASPHALT_PATH)
	world = owner_world
	add_child(_junctions)
	add_child(_guide)
	_guide.setup(world.view_tile())
	var disc := CylinderMesh.new()
	disc.top_radius = world.view_tile() * 0.3
	disc.bottom_radius = disc.top_radius
	disc.height = 0.12
	_entrance.mesh = disc
	_entrance.material_override = GroundShape.material(Color("#efbf64"))
	add_child(_entrance)
	_entrance.position = world.to_view(world.roads.entrance) + Vector3.UP * 0.09
	_entrance.hide()
	var start := Vector2(
		world.roads.entrance.x - world.roads.width * 0.5, world.command_post.sim_bounds().end.y
	)
	var span := Vector2(world.roads.width, world.roads.entrance.y - start.y)
	var strip := PackedVector2Array(
		[start, start + Vector2.RIGHT * span.x, start + span, start + Vector2.DOWN * span.y]
	)
	_apron.mesh = GroundShape.surface([strip], world.map_def.view_scale)
	_apron.material_override = _asphalt
	_apron.position.y = 0.042
	add_child(_apron)
	_apron.hide()
	world.roads.changed.connect(_sync_surfaces)
	world.grid.changed.connect(_invalidate)
	world.plots.changed.connect(_invalidate)


func select(next: Mode = Mode.STRAIGHT) -> void:
	world.build_tool.clear()
	world.plot_tool.clear()
	mode = next
	active = true
	if points.size() > 1:
		points.resize(1)
	_entrance.show()
	_refresh_step()


func clear() -> void:
	active = false
	_entrance.hide()
	points.clear()
	_chained = false
	_refresh_step()


func step_back() -> void:
	if points.is_empty():
		clear()
		return
	points.resize(points.size() - 1)
	if points.is_empty():
		_chained = false
	_refresh_step()


func _needs_handle() -> bool:
	return points.size() == 1 and mode != Mode.STRAIGHT and not (mode == Mode.FREEFORM and _chained)


func _refresh_step() -> void:
	_invalidate()
	_guide.reset()
	if not active:
		hint = ""
	elif points.is_empty():
		hint = "Click the start of the street."
	elif _needs_handle():
		hint = "Click to set the bend direction. Right-click to step back."
	else:
		hint = "Click to build and continue. Right-click to step back."


func _invalidate() -> void:
	_last_cursor = Vector2.INF


func _aim(cursor: Vector2, connection: Vector2) -> Vector2:
	if connection.is_finite():
		return connection
	if not angle_snap or points.is_empty():
		return cursor
	var origin := points[-1]
	var offset := cursor - origin
	var axis := _direction if points.size() == 1 else points[0].direction_to(points[1])
	var angle := axis.angle_to(offset)
	var guide := snappedf(angle, world.roads.angle_step)
	if absf(guide - angle) > world.roads.angle_tolerance:
		return cursor
	return origin + axis.rotated(guide) * offset.length()


func _controls(endpoint: Vector2) -> PackedVector2Array:
	var result := points.duplicate()
	if mode == Mode.FREEFORM and _chained and points.size() == 1:
		result.append(points[0] + _direction * points[0].distance_to(endpoint) * 0.5)
	result.append(endpoint)
	return result


func _target(cursor: Vector2) -> Vector2:
	return Vector2.INF if _needs_handle() else world.roads.connection_point(cursor)


func place(cursor: Vector2) -> void:
	var end := _aim(cursor, _target(cursor))
	if points.is_empty():
		points.append(end)
		var hit := world.roads.nearest(end, StreetCrossings.EPSILON)
		_direction = hit.get("tangent", Vector2.RIGHT)
	elif _needs_handle():
		if points[0].distance_to(end) < world.roads.width * 0.15:
			hint = "Move the bend handle farther from the start."
			return
		points.append(end)
	else:
		var controls := _controls(end)
		var curved := mode != Mode.STRAIGHT
		var street := world.roads.add_road(controls, false, curved)
		if street == null:
			hint = world.roads.preview(controls, false, curved).error
			return
		_direction = controls[-2].direction_to(end)
		points = PackedVector2Array([end])
		_chained = true
	_refresh_step()


func _process(_delta: float) -> void:
	if not active:
		return
	var viewport := get_viewport()
	var mouse := viewport.get_mouse_position()
	if (
		not viewport.get_visible_rect().has_point(mouse)
		or viewport.gui_get_hovered_control() != null
	):
		_hide_preview()
		return
	var hit: Variant = world.camera.ground_at(mouse)
	if hit == null:
		_hide_preview()
		return
	_update_preview(world.to_sim(hit), mouse)


func _update_preview(cursor: Vector2, mouse: Vector2) -> void:
	if cursor.is_equal_approx(_last_cursor):
		return
	_last_cursor = cursor
	var target := _target(cursor)
	var end := _aim(cursor, target)
	var handles := PackedVector2Array()
	var road: Street
	var caption := ""
	if not points.is_empty():
		var controls := _controls(end)
		if _needs_handle():
			handles = controls
			caption = "Bend direction"
		else:
			road = world.roads.preview(controls, false, mode != Mode.STRAIGHT)
			if controls.size() == 3:
				handles = controls
			if road.error.is_empty():
				var axis := (
					_direction if controls.size() == 2 else controls[0].direction_to(controls[1])
				)
				var angle := absf(rad_to_deg(axis.angle_to(controls[-1] - controls[-2])))
				caption = "%.1f m   %.0f°" % [road.length_m(world.map_def.view_scale), angle]
			else:
				caption = road.error
	_guide.draw(world, road, handles, target, caption, mouse)


func _hide_preview() -> void:
	if _last_cursor.is_finite():
		_guide.reset()
	_invalidate()


func _unhandled_input(event: InputEvent) -> void:
	if not active:
		return
	if event is InputEventMouseButton and event.is_action_pressed("place"):
		var hit: Variant = world.camera.ground_at(event.position)
		if hit != null:
			place(world.to_sim(hit))
	elif event.is_action_pressed("cancel") and event is InputEventMouseButton:
		step_back()
	elif event.is_action_pressed("cancel"):
		clear()
	else:
		return
	get_viewport().set_input_as_handled()


func _sync_surfaces() -> void:
	_apron.visible = not (
		world.roads.graph.get(world.roads.entrance, PackedVector2Array()).is_empty()
	)
	for id: int in _surfaces.keys():
		if not world.roads.roads.has(id):
			_surfaces[id].queue_free()
			_surfaces.erase(id)
	for road: Street in world.roads.roads.values():
		if _surfaces.has(road.id):
			continue
		var surface := StreetSurface.new()
		surface.draw_street(road, world.map_def.view_scale)
		add_child(surface)
		_surfaces[road.id] = surface
	_junctions.draw_junctions(world.roads, world.map_def.view_scale)
	_last_cursor = Vector2.INF
