class_name RoadTool
extends Node3D
## Edits a temporary street and renders its full width before committing it.

const HELP := "Click street points • Enter to finish • Backspace to undo • Esc to cancel"
const VALID := Color(0.35, 0.82, 0.63, 0.72)
const INVALID := Color(0.91, 0.30, 0.22, 0.66)

var active := false
var points := PackedVector2Array()
var hint := ""
var world: World

var _surfaces: Dictionary[int, MeshInstance3D] = {}
var _ghost := MeshInstance3D.new()
var _apron := MeshInstance3D.new()
var _entrance := MeshInstance3D.new()
var _last_cursor := Vector2.INF
var _preview_material := GroundShape.material(VALID)
var _asphalt := GroundShape.material(Color("#55565a"))


func setup(owner_world: World) -> void:
	world = owner_world
	add_child(_ghost)
	_ghost.position.y = 0.08
	_ghost.material_override = _preview_material
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


func select() -> void:
	world.build_tool.clear()
	world.plot_tool.clear()
	active = true
	hint = "Start at the gold marker by Station 4 or click open ground."
	_entrance.show()


func clear() -> void:
	active = false
	points.clear()
	_ghost.mesh = null
	_entrance.hide()
	_last_cursor = Vector2.INF
	hint = ""


func undo() -> void:
	if not points.is_empty():
		points.resize(points.size() - 1)
	_last_cursor = Vector2.INF
	hint = HELP


func add_point(point: Vector2) -> void:
	if points.is_empty():
		point = world.roads.snap_endpoint(point)
	if not points.is_empty() and points[-1].distance_to(point) < world.roads.min_segment:
		hint = "Move farther from the previous point."
		return
	points.append(point)
	_last_cursor = Vector2.INF
	hint = HELP


func finish() -> bool:
	if world.roads.add_road(points) == null:
		hint = world.roads.preview(points).error
		return false
	points.clear()
	_ghost.mesh = null
	_last_cursor = Vector2.INF
	hint = "Street built. Click to start another."
	return true


func _process(_delta: float) -> void:
	if not active:
		return
	var mouse := get_viewport().get_mouse_position()
	if not get_viewport().get_visible_rect().has_point(mouse):
		_ghost.hide()
		return
	var hit: Variant = world.camera.ground_at(mouse)
	if hit == null or points.is_empty():
		_ghost.hide()
		return
	var cursor := world.to_sim(hit)
	if cursor.is_equal_approx(_last_cursor) and _ghost.visible:
		return
	_last_cursor = cursor
	var candidates := points.duplicate()
	if cursor.distance_to(points[-1]) >= world.roads.min_segment:
		candidates.append(cursor)
	var road := world.roads.preview(candidates)
	_ghost.mesh = (
		GroundShape.surface(road.strips, world.map_def.view_scale)
		if not road.strips.is_empty()
		else null
	)
	_preview_material.albedo_color = VALID if road.error.is_empty() else INVALID
	_ghost.show()
	if candidates.size() >= 2:
		hint = HELP if road.error.is_empty() else road.error


func _unhandled_input(event: InputEvent) -> void:
	if not active:
		return
	if event.is_action_pressed("cancel"):
		clear()
	elif (
		event is InputEventKey
		and event.pressed
		and not event.echo
		and event.keycode in [KEY_ENTER, KEY_KP_ENTER]
	):
		finish()
	elif (
		event is InputEventKey
		and event.pressed
		and not event.echo
		and event.keycode == KEY_BACKSPACE
	):
		undo()
	elif event.is_action_pressed("place") and event is InputEventMouseButton:
		var hit: Variant = world.camera.ground_at(event.position)
		if hit != null:
			add_point(world.to_sim(hit))
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
		var surface := MeshInstance3D.new()
		surface.mesh = GroundShape.surface(road.strips, world.map_def.view_scale)
		surface.position.y = 0.045
		surface.material_override = _asphalt
		add_child(surface)
		_surfaces[road.id] = surface
	_last_cursor = Vector2.INF
